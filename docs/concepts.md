# Key Concepts

There are a number of key concepts for building Generative AI applications with Azure Cosmos DB within this solution:

- Generating text representations of items.
- Generating and storing vectors.
- Generating contexts for completions.
- Generating completions.
- Storing chat conversations.
- Caching.
- Natural language system commands.

Item text representations and vectors are generated when data is inserted into Azure Cosmos DB, then stored in an Azure Cosmos DB vector index that is used for vector searches. Users then ask natural language questions using the web-based chat user interface (User Prompts). These prompts are then vectorized and used to search the vectorized data. The search results are then sent, along with some of the conversation history, to Azure OpenAI Service to generate a response (Completion) back to the user. New completions are also stored in a semantic cache that is consulted for each new user prompt. All of the User Prompts and Completions are stored in a Cosmos DB container along with the number of tokens consumed by each Prompt and Completion. A Chat Session contains all of the prompts and completions and a running total of all tokens consumed for that session. In a production environment users would only be able to see their own sessions but this solution shows all sessions from all users.

## Generating text representations of items

One of the challenges encountered with Generative AI solutions that use the RAG pattern is ensuring that data used has the best possible textual representation. For structured and semi-structured data (e.g., items stored in Cosmos DB databases), the challenge is different than it is for documents. Our goal is to propose a generic enough approach that can be easily adapted to different data models and scenarios.

> [!NOTE]
> LLMs are capable of interpreting other formats than text, but this solution focuses on text.

In the particular case of items stored in Azure Cosmos DB databases, the above-mentioned challenge translates into:

- Selecting the relevant fields to be used as text representations.
- Transforming the values of the selected fields into a single text representation.

The solution provides an Azure Cosmos DB generic change feed handler (`Infrastructure.Services.CosmosDBService.GenericChangeFeedHandler()`) that can be used to intercept changes in any Cosmos DB container. The `MSCosmosDBOpenAI.CosmosDB.MonitoredContainers` application setting provides the comma-separated list of containers to be monitored by the generic handler.

The selection of fields and the transformation of their values is performed by an item transformer. An item transformer is a class that must implement the `Common.Interfaces.IItemTransformer` interface. Some of the key elements produced by an instance of an item transformer are:

- `EmbeddingId` - the unique identifier of the item in the vector index.
- `EmbeddingPartitionKey` - the partition key of the item in the vector index (this is specific to using Azure Cosmos DB as your vector index store).
- `TextToEmbed` - the text representation of the item that will be embedded into the vector space.
- `VectorIndexName` - the name of the vector index where the vectorized item will be stored (in the case of Azure Cosmos DB, this represents the container name). This allows us to configure the mapping of item types to vector indexes (e.g., store customer and sales order vectors in one index and product vectors in another).

In addition to the `IItemTransformer` interface, the solution also provides a sample implementation of it, in the form of the `Common.Services.ModelRegistryItemTransformer` class, which is created using the `Common.Services.ItemTransformerFactory` factory class (this is where other item transformers can be added in case the default one is not suitable for a specific scenario).

The `ModelRegistryItemTransformer` relies on metadata provided by a simple model registry, the `Common.Models.ModelRegistry` class. The model registry is a simple, code-first dictionary that maps item types to the fields that should be used as text representations. One of the possible improvements to this solution is to replace the code-first model registry with a more flexible, data-driven one (e.g., a Cosmos DB container that stores the mapping between item types and fields).

Once the generic change feed handler intercepts the newly added item and wraps it into an instance of the item transformer, we are ready to move to the next step of the process - generating and storing the vector representation of the item.

## Generating vectors

The vectorization capability is provided by the `Infrastructure.Services.SemanticKernelRAGService.AddMemory()` method.

The `SementicKernelRAGService` class maintains two categories of vector memory stores:

- Long-term - the vector stores that contain the vector representations of the items stored in the Cosmos DB monitored containers.
- Short-term (volatile) - the vector store that contains the vector representations of text originating from the blob storage.

> [!NOTE]
> The short-term memory store reloads the raw data each time the service is restarted, which can be considered a limitation. The purpose of having this type of approach in the solution is to show how other sources of content than Cosmos DB (blob storage in this case) can be used to augment the context provided to the LLM.

Regardless of whether they are long-term or short-term, all vector memory stores are implemented as instances of the `SemanticKernel.Plugins.Memory.VectorMemoryStore` class. The `VectorMemoryStore` class relies on the following:

- An `IMemoryStore` implementation that provides the basic operations for the vector memory store. This can be either an `AzureCosmosDBNoSqlMemoryStore` (persists the vector index in an Azure Cosmos DB container) or a `VolatileMemoryStore` (keeps the vector index in memory).
- An `ITextEmbeddingGenerationService` implementation that generates the text embeddings for the items. This is always an instance of the `AzureOpenAITextEmbeddingGenerationService` provided by Semantic Kernel which abstracts the interaction with the Azure OpenAI Service embeddings API. The `MSCosmosDBOpenAI.OpenAI.EmbeddingsDeployment` application setting provides the name of the Azure OpenAI embedding model deployment to be used for embedding.

> [!NOTE]
> The deployment process will use the `text-embedding-3-large` emebdding model.

Based on the above, the `AddMemory(IItemTransformer itemTransformer)` method of the `VectorMemoryStore` class will generate the text embeddings for the item provided by the item transformer and store them in the vector memory store. The `SemanticKernelRAGService`'s `AddMemory()` method will call the `AddMemory()` method of the vector memory store that corresponds to the item transformer's `VectorIndexName`.

## Generating contexts for completions

The web-based front-end provides users the means for searching the vectorized retail bike data for this solution. The basic process that unfolds is the following:

- In the chat UI, a user starts a new chat session then types in a natural language question.
- The text is sent to Azure OpenAI Service embeddings API to generate the associated vector.
- The vector is then used to perform a vector search on the vector memory stores (Azure Cosmos DB containers and the volatile memory store).
- The query response which includes the original source data is sent to Azure OpenAI Service to generate a completion which is then passed back to the user as a response.

The actual implementation of the process described above is done using the abstractions provided by the Semantic Kernel orchestrator. This allows for a much more sophisticated and robust approach that uses the power of LLMs in a way that is more efficient and effective. The core Semantic Kernel concept that is used is the [plugin](https://learn.microsoft.com/en-us/semantic-kernel/concepts/plugins/?pivots=programming-language-csharp). Instead of manually interogating the vector indexes and building the RAG pattern context, plugins are used to generate the individual parts of the context associated with each vector memory store. The `SemanticKernel.Plugins.Core.MemoryStoreContextPlugin` is a plugin that provides the capability to retrieve memories from an underlying `VectorMemoryStore` instance. It derives from the `PluginBase` which is base class that provides three key metadata properties for plugins: a name, a description, and a prompt name.

The `CreateMemoryStoresAndPlugins()` method of the `SemanticKernelRAGService` class is responsible for creating the vector memory stores and the associated plugins. The method is called in the constructor of the `SemanticKernelRAGService` class. The `VectorStoreSettings` class is used to map the configuration settings from the application settings sections associated with the memory stores (e.g., `MSCosmosDBOpenAI.ModelRegistryKnowledgeIndexing` with its entries for each Cosmos DB vector index container, `MSCosmosDBOpenAI.StaticKnowledgeIndexing` for the short-term memories, and `MSCosmosDBOpenAI.SemanticCacheIndexing` for the semantic cache). These configuration settings provide the two very important properties for the plugins: the name of the plugin (originating from the `IndexName` setting) and the description of the plugin (originating from the `Description` setting).

> [!NOTE]
> The semantic cache functionality is described in more detail in the [Semantic Cache](#semantic-cache) section.

Based on all of the above, the flow for generating the context for completions is as follows:

- Based on the user's question, we use the LLM to dynamically determine the list of plugins that should be used to generated the RAG context. A special plugin, the `SemanticKernel.Plugins.Core.ContextPluginsListPlugin`, is used to compile the list of names and descriptions of the plugins that are available for context generation. This plugin is invoked by the context selector prompt and results in a list of plugins whose descriptions are best aligned with the user's question.
- The list of selected context-generation plugins is fed into the `SemanticKernel.Plugins.Core.KnowledgeManagementContextPlugin` which is responsible for invoking those plugins and generating the context for the RAG completion.
- The `KnowledgeManagementContextPlugin` is invoked by the main RAG prompt and generates the context for the completion by invoking the selected plugins and aggregating the results. The context is then passed to the LLM to generate the completion.

This approach has the following important advantages:

- The generation of the RAG context is truly dynamic and can be adapted to the user's question.
- The context can be generated from multiple sources (Cosmos DB containers, volatile memory store) and can be easily extended to include other sources.
- The configurability of the `ModelRegistry` allows for easy adaptation to different data models and scenarios. Item types from the data model can be consolidated in a flexible way to generate multiple vector indexes, which in turn can be selected as needed to generated the slices of the RAG context. 


## Managing conversational context and history

Large language models such as GPT-4(o) do not keep any history of what prompts users sent it, or what completions it generated. It is up to the developer to do this. Keeping this history is necessary for two reasons. First, it allows users to ask follow-up questions without having to provide any context, while also allowing the user to have a conversation with the model. Second, the conversation history is useful when performing vector searche on data as it provides additional detail on what the user is looking for. As an example, if I asked our Intelligent Retail Agent what bikes it had available, it would return for me all of the bikes in stock. If I then asked, "what colors are available?", if I did not pass the first prompt and completion, the vector search would not know that the user was asking about bike colors and would likely not produce an accurate or meaningful response.

Another concept surfaced with conversation management centers around tokens. All calls to Azure OpenAI Service are limited by the number of tokens in a request and response. The number of tokens is dependant on the model being used. You see each model and its token limit on OpenAI's website on their [Models Overview page](https://platform.openai.com/docs/models/overview).

The class that manages conversational history is called [ContextBuilder](https://github.com/Azure/BuildYourOwnCopilot/blob/main/src/SemanticKernel/Chat/ContextBuilder.cs). This class is used to gather the most convesation history up to the token limits defined in configuration, then returns it as a string separating each prompt and completion with a new line character. The new line is not necessary for the LLM, but makes it more readable for a user when debugging. The class is also keeping track of the number of tokens corresponding to the conversation history, and uses it to make sure the overall number of tokens in a request is within the limits.

The `ContextBuilder` class is used by the `KnowledgeManagementContextPlugin` to generate the final version of the RAG context (once the plugin has finished invoking all the relevant context-generation plugins).

### Vectorizing the user prompt

In a vector search solution, the filter predicate for any query is a vector. This means that the text the user types in to the chat window must first be vectorized before the vector search can be done. This is accomplished in the [SemanticKernelRAGService](https://github.com/Azure/BuildYourOwnCopilot/blob/main/src/Infrastructure/Services/SemanticKernelRAGService.cs) in the solution during the processing of the [GetResponse()](https://github.com/Azure/BuildYourOwnCopilot/blob/main/src/Infrastructure/Services/SemanticKernelRAGService.cs#L302) method. This method takes as inputs the user prompt (as a string) and the message history of the conversation (as a list of strings) returns a `CompletionResult` object that contains the completion text, the number of tokens used in the request and response, as well as other relevant information.

To understand the way the user prompt is vectorized, make sure you read through and understand the flow described in [Generating contexts for completions](#generating-contexts-for-completions).

### Doing the vector search

The vector search is the key function in this solution and is done against Azure Cosmos DB vector store collections and in-memory vector stores in this solution. The function itself is rather simple and only takes and array of vectors with which to do the search. You can see the vector search at work by debugging the container instances remotely or running locally. For the Azure Cosmos DB vector stores, set a break point on [GetNearestMatchesAsync()](https://github.com/Azure/BuildYourOwnCopilot/blob/main/src/SemanticKernel/Memory/AzureCosmosDBNoSqlMemoryStore.cs#L374), then step through each line to see how of the function calls to see the search and returned data.

To understand the way the vector searches are performed, make sure you read through and understand the flow described in [Generating contexts for completions](#generating-contexts-for-completions).

### Token management

One of the more challenging aspects to building RAG Pattern solutions is managing the tokens to stay within the maximum number of tokens that can be consumed in a single request (prompt) and response (completion). It's possible to build a prompt that consumes all of the tokens in the requests and leaves too few to produce a useful response. It's also possible to generate an exception from the Azure OpenAI Service if the request itself is over the token limit. You will need a way to measure token usage before sending the request. This is handled in the [OptimizePromptSize()](https://github.com/Azure/BuildYourOwnCopilot/blob/main/src/SemanticKernel/Chat/ContextBuilder.cs#L99) method in the `ContextBuilder` class. This method uses a .NET tokenizer that closely follows the behavior of the one used by OpenAI, [MicrosoftMLTokenizer](https://github.com/Azure/BuildYourOwnCopilot/blob/main/src/SemanticKernel/Chat/MicrosoftMLTokenizer.cs). The utility takes text and determines the number of tokens required to represent it. Here is the flow of this method.

1. Measure the amount of tokens for the vector search results (RAG data).
2. Measure the amount of tokens for the user prompt. This data is also used to capture what the user prompt tokens would be if processed without any additional data and stored in the user prompt message in the completions collection (more on that later).
3. Calculate if the amount of tokens used by the `search results` plus the `user prompt` plus the `conversation` + `completion` is greater than what the model will accept. If it is greater, then calculate how much to reduce the amount of data and `decode` the vector array we generated from the search results, back into text.
4. Finally, return the text from our search results as well as the number of tokens for the last User Prompt (this will get stored a bit later).

### Generate the completion

This is the most critical part of this entire solution, generating a chat completion from Azure OpenAI Service using one of its [GPT models](https://platform.openai.com/docs/guides/gpt) wherein the Azure OpenAI Service will take in all of the data we've gathered up to this point, then generate a response or completion which the user will see. All of this happens in the [SemanticKernelRAGService](https://github.com/Azure/BuildYourOwnCopilot/blob/main/src/Infrastructure/Services/SemanticKernelRAGService.cs) in the [GetResponse()](https://github.com/Azure/BuildYourOwnCopilot/blob/main/src/Infrastructure/Services/SemanticKernelRAGService.cs#L302) method. 

This method takes the user prompt and the search results and builds a `System Prompt` with the search data, as well as a user prompt that includes the conversation history plus the user's last question (prompt). The call is then made to the service which returns a `Chat Completion` object which contains the response text itself, plus the number of tokens used in the request (prompt) and the number of tokens used to generate the response (completion). 

One thing to note here is it is necessary to separate the number of tokens from the Prompt with the data versus the number of tokens from the text the user types into the chat interface. This is due to the need to accurately estimate the number of tokens for *just the text* of the user prompt and not for the data.

To understand the way the completions are generated, make sure you read through and understand the flow described in [Generating contexts for completions](#generating-contexts-for-completions).

### Saving the results

The last part is to save the results of both the user prompt and completion as well as the amount of tokens used. All of the conversational history and the amount of tokens used in each prompt and completion is stored in the completions collection in the Azure Cosmos DB database in this solution. The call to the service is made by another method within `ChatService` called [AddPromptCompletionMessagesAsync()](https://github.com/Azure/BuildYourOwnCopilot/blob/main/src/Infrastructure/Services/ChatService.cs#L171). This method creates two new [Message](https://github.com/Azure/BuildYourOwnCopilot/blob/main/src/Common/Models/Chat/Message.cs) objects and stores them in a local cache of all the Sessions and Messages for the application. It then adds up all of the tokens used in the [Session](https://github.com/Azure/BuildYourOwnCopilot/blob/main/src/Common/Models/Chat/Session.cs) object which keeps a running total for the entire session.

The data is then persisted to the Cosmos DB database in the [UpsertSessionBatchAsync()](https://github.com/Azure/BuildYourOwnCopilot/blob/main/src/Infrastructure/Services/CosmosDbService.cs#L346) method. This method creates a new transaction then updates the `Session` document and inserts two new `Message` documents into the completions collection.

## Semantic cache

The role of the semantic cache is to make sure there are no unnecessary calls to the LLMs, thus optimizing the number of tokens consumed. It does this by:

- Storing sequences of completions and their associated vectorized forms in an Azure Cosmos DB vector index store.
- Comparing incoming user prompts and completions (from conversation histories) with the sequences stored in the semantic cache by using vector-based similarity measures.
- Returning the completion from the cache if the similarity measure is above a certain (usually very high) threshold.

The semantic cache is implemented by the `Infrastructure/Services/SemanticCacheService.cs` class. Internally, it uses a `VectorMemoryStore` instance to manage the vector index store where the completions are stored. The vector memory store relies on an `AzureCosmosDBNoSqlMemoryStore` instance to persist the vector index in an Azure Cosmos DB container and an `AzureOpenAITextEmbeddingGenerationService` instance to generate the text embeddings. The settings controlling the behavior of the semantic cache are stored in the `MSCosmosDBOpenAI.SemanticCacheIndexing` application settings section.

The semantic cache is integrated into main flow as follows:

- Before doing anything else in its `GetResponse()` method, the `SemanticKernelRAGService` class checks if the semantic cache can provide a completion for the current user prompt and conversation history. If it can, the completion is returned and the whole process completes without any further LLM calls.
- If there is no suitable completion in the semantic cache, the `SemanticKernelRAGService` class proceeds with the normal flow of generating the context for the completion and calling the LLM.
- After the completion is generated, the semantic cache is updated with the new completion and its associated vectorized form.

> [!NOTE]
> Within its `GetCacheItem()` method, the `SemanticCacheService` handles one particular case, the one where the user just repeates the previous response. In this case, the semantic cache will return the previous response as the completion. This is a great example how the semantic cache itself can be enhanced to provide more sophisticated behavior.

## Natural language system commands

With the addition of the semantic cache, the solution also needed to provide a way to clear the cache and set a different threshold for the similarity measure used to match cache items. Instead of building user interface components and backend API methods to support these requirements, the solution provides a set of natural language system commands that can be used in the chat UI. The following table lists the available system commands:

| Command | Description | User Prompt 
| --- | --- | --- |
| Reset semantic cache | Resets the semantic cache by removing all entries from the vector store index. | `Can you please reset the semantic cache?` |
| Set semantic cache similarity threshold value | Sets the similarity threshold used by the semantic cache to match cache items to a specified value. The new value is not persisted as a configuration value and is in effect only until the backend API service is restarted. | `Can you set the semantic cache similarity score to 0.82?` |

> [!NOTE]
> Since the completions returned by system commands can interfere with the normal flow of conversations, it is recommended to use them in separate conversation.

The system commands are implemented using the `SystemCommandPlugin` class, derived from the `PluginBase` class. At the end of the `CreateMemoryStoresAndPlugins` method of the `SemanticKernelRAGService` class, several instances of the `SystemCommandPlugin` class are created and added to the list of plugins that are available for execution. The configuration for these plugins (including the critical name and description) are provided by the `MSCosmosDBOpenAI.SystemCommandPlugins` application settings section.

When determining which plugins to use for generating the RAG context, some of the system command plugins might be selected as well, provided the user prompt is a match for the system command. If any system command plugins are selected, they are executed via the `ExecuteSystemCommands()` method and all the other plugins are ignored. In this case, the flow will end with the execution of the system command plugins.

If the `Reset semantic cache` system command is executed, it will simply result in the removal of all entries from the vector store index.

If the `Set semantic cache similarity threshold value` system command is executed, it will first attempt to extract the specific value from the user prompt. If the value is successfully extracted, it will be used to set the similarity threshold for the semantic cache. The new value is not persisted as a configuration value and is in effect only until the backend API service is restarted. The way it extracts the value is by using a specialized system prompt that is specially designed for the purpose and sent to the LLM.

> [!NOTE]
> The system commands are a great example of how the solution can be extended to provide additional functionality without the need to build new UI components or backend API methods. They also demonstrate how the Semantic Kernel orchestrator can be used to execute different types of plugins based on the user's input.