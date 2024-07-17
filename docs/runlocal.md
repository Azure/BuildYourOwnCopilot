# Run locally and debug

This solution can be run locally post Azure deployment. To do so, use the steps below.

## Configure local settings

- In the `UserPortal` project, make sure the content of the `appsettings.json` file is similar to this:

    ```json
    {
        "DetailedErrors": true,
        "Logging": {
            "LogLevel": {
            "Default": "Information",
            "Microsoft.AspNetCore": "Warning"
        }
        },
        "AllowedHosts": "*",
        "MSCosmosDBOpenAI": {
            "ChatManager": {
                "APIUrl": "https://localhost:63279",
                "APIRoutePrefix": ""
            }
        }
    }
    ```

- In the `ChatAPI` project, make sure the content of the `appsettings.json` file is similar to this:

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.SemanticKernel": "Error"
    },
    "ApplicationInsights": {
      "LogLevel": {
        "Default": "Information",
        "Microsoft.AspNetCore": "Warning",
        "Microsoft.SemanticKernel": "Error"
      }
    }
  },
  "AllowedHosts": "*",
  "MSCosmosDBOpenAI": {
    "ModelRegistryKnowledgeIndexing": {
      "customer-vector-store": {
        "Description":  "Provides content that can be used to build context around customers and sales orders. Includes information on customer properties like unique identifier, first name, last name, email address, phone number, address, and the count of sales orders. Also includes information on sales orders like customer unique identifier, order date, shipping date, and the list of product SKUs, names, prices and quantities.",
        "IndexName": "customer-vector-store",
        "VectorDataType": "float32",
        "Dimensions": 1536,
        "DistanceFunction": "cosine",
        "EmbeddingPath": "/embedding",
        "VectorIndexType": "quantizedFlat",
        "MaxVectorSearchResults": 10,
        "MinRelevance": 0.7
      },
      "product-vector-store": {
        "Description": "Provides content that can be used to build context around products. Includes information on product names, product details, product categories, product prices, product SKUs, and product tags.",
        "IndexName": "product-vector-store",
        "VectorDataType": "float32",
        "Dimensions": 1536,
        "DistanceFunction": "cosine",
        "EmbeddingPath": "/embedding",
        "VectorIndexType": "quantizedFlat",
        "MaxVectorSearchResults": 10,
        "MinRelevance": 0.7
      }
    },
    "StaticKnowledgeIndexing": {
      "Description": "Provides information on product return policies and product shipping policies.",
      "IndexName": "short-term",
      "Dimensions": 1536,
      "MaxVectorSearchResults": 10,
      "MinRelevance": 0.55
    },
    "SemanticCacheIndexing": {
      "Description": "Semantic cache.",
      "IndexName": "cache-vector-store",
      "VectorDataType": "float32",
      "Dimensions": 1536,
      "DistanceFunction": "cosine",
      "EmbeddingPath": "/embedding",
      "VectorIndexType": "quantizedFlat",
      "MaxVectorSearchResults": 1,
      "MinRelevance": 0.95
    },
    "SemanticCache": {
      "ConversationContextMaxTokens": 2000
    },
    "SystemCommandPlugins": [
      {
        "Name": "reset-semantic-cache",
        "Description": "Provides the capability to reset the semantic cache."
      },
      {
        "Name": "set-semantic-cache-similarity-score",
        "Description": "Provides the capability to set the similarity score used by the semantic cache.",
        "PromptName": "SystemCommands.SetSemanticCacheSimilarityScore"
      }
    ],
    "OpenAI": {
      "CompletionsDeployment": "completions",
      "CompletionsDeploymentMaxTokens": 8096,
      "EmbeddingsDeployment": "embeddings",
      "EmbeddingsDeploymentMaxTokens": 8191,
      "ChatCompletionPromptName": "RetailAssistant.Default",
      "ShortSummaryPromptName": "Summarizer.TwoWords",
      "ContextSelectorPromptName":  "ContextSelector.Default",
      "PromptOptimization": {
        "CompletionsMinTokens": 50,
        "CompletionsMaxTokens": 300,
        "SystemMaxTokens": 1500,
        "MemoryMinTokens": 1500,
        "MemoryMaxTokens": 7000,
        "MessagesMinTokens": 100,
        "MessagesMaxTokens": 200
      }
    },
    "TextSplitter": {
      "TokenizerEncoder": "cl100k_base",
      "ChunkSizeTokens": 500,
      "OverlapSizeTokens": 50
    },
    "CosmosDB": {
      "Containers": "completions, customer, product",
      "MonitoredContainers": "customer, product",
      "Database": "vsai-database",
      "ChangeFeedLeaseContainer": "leases"
    },
    "DurableSystemPrompt": {
      "BlobStorageContainer": "system-prompt"
    },
    "BlobStorageMemorySource": {
      "ConfigBlobStorageContainer": "memory-source",
      "ConfigFilePath": "BlobMemorySourceConfig.json"
    }
  }
}
```

- In the `ChatAPI` project, create an `appsettings.Development.json` file with the following content (replace all `<...>` placeholders with the values from your deployment):

```json
{
    "MSCosmosDBOpenAI": {
        "OpenAI": {
            "Endpoint": "https://<...>.openai.azure.com/",
            "Key": "<...>"
        },
        "CosmosDB": {
            "Endpoint": "https://<...>.documents.azure.com:443/",
            "Key": "<...>"
        },    
        "DurableSystemPrompt": {
            "BlobStorageConnection": "<...>"
        },
        "BlobStorageMemorySource": {
            "ConfigBlobStorageConnection": "<...>"
        }
    }
}
```

> [!NOTE]
> The `BlobStorageConnection` and `ConfigBlobStorageConnection` values can be found in the Azure Portal by navigating to the Storage Account created by the deployment (the one that has a container named `system-prompt`) and selecting the `Access keys` blade. The value is the `Connection string` for the `key1` key.

## Using Visual Studio

To run locally and debug using Visual Studio, open the solution file.

Before you can start debugging, you need to set the startup projects. To do this, right-click on the solution in the Solution Explorer and select `Configure Startup Projects...`. In the dialog that opens, select `Multiple startup projects` and set the `Action` for the `ChatAPI` and `UserPortal` projects to `Start`.

Also, make sure the newly created `appsettings.Development.json` file is copied to the output directory. To do this, right-click on the file in the Solution Explorer and select `Properties`. In the properties window, set the `Copy to Output Directory` property to `Copy always`..

You are now ready to start debugging the solution locally. To do this, press `F5` or select `Debug > Start Debugging` from the menu.

**NOTE**: With Visual Studio, you can also use alternate ways to manage the secrets and configuration. For example, you can use the `Manage User Secrets` option from the context menu of the `ChatAPI` project to open the `secrets.json` file and add the configuration values there.
