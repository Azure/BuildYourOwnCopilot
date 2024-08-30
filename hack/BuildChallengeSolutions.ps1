
$excludedFolders = @(
    "\.vs",
    "\ChatAPI\bin",
    "\ChatAPI\manifests",
    "\ChatAPI\obj",
    "\Common\bin",
    "\Common\obj",
    "\Infrastructure\bin",
    "\Infrastructure\obj",
    "\SemanticKernel\bin",
    "\SemanticKernel\obj",
    "\UserPortal\bin",
    "\UserPortal\obj"
)

function Copy-Files {
    param(
        [string]$sourcePath,
        [string]$targetPath
    )

    Get-ChildItem $sourcePath -File | ForEach-Object {
        $file = $_.Name
        $source = Join-Path -Path $sourcePath -ChildPath $file
        $target = Join-Path -Path $targetPath -ChildPath $file
        Write-Host "Copying $source to $target"
        Copy-Item -Path $source -Destination $target -Force
    }
}

function Copy-SolutionFolders {
    param(
        [string]$sourceRelativePath,
        [string]$sourcePath,
        [string]$targetPath
    )

    if (-not (Test-Path -Path $targetPath)) {
        New-Item -ItemType Directory -Path $targetPath
    }

    Copy-Files -sourcePath $sourcePath -targetPath $targetPath

    Get-ChildItem $sourcePath -Directory | Where-Object { (Join-Path -Path $sourceRelativePath -ChildPath $_.Name) -notin $excludedFolders } | ForEach-Object {
        $folder = $_.Name
        $sourceRelative = Join-Path -Path $sourceRelativePath -ChildPath $folder
        $source = Join-Path -Path $sourcePath -ChildPath $folder
        $target = Join-Path -Path $targetPath -ChildPath $folder
        Write-Host "Copying $source to $target"
        Copy-SolutionFolders -sourceRelativePath $sourceRelative -sourcePath $source -targetPath $target
    }
}

function Change-CodeFile {
    param(
        [string] $filePath,
        [hashtable[]] $replacements,
        [System.Collections.ArrayList] $docs
    )

    Write-Output "Starting to change file $filePath..."

    $lines = New-Object System.Collections.ArrayList(, (Get-Content -Path $filePath))

    foreach ($replacement in $replacements) {
        $exerciseContext = "[Challenge $($replacement.ChallengeNumber)][Exercise $($replacement.ChallengeNumber).$($replacement.ExerciseNumber).$($replacement.ExerciseStepNumber)]"
        $startingLinePattern = $replacement.StartingLinePattern
        $removedLinesCount = $replacement.RemovePatternLine ? $replacement.RemovedLinesCount + 1 : $replacement.RemovedLinesCount
        $replacementLines = [System.Collections.ArrayList]$replacement.ReplacementLines

        $docsIndex = $docs.Add("## $exerciseContext")

        Write-Host "Line pattern lookup: $startingLinePattern"

        $replacementsCount = 0
        $lineIndex = $lines.IndexOf(($lines | Where-Object { $_.Trim() -ieq $startingLinePattern } | Select-Object -First 1))

        while ($lineIndex -ge 0) {

            $replacementsCount++

            Write-Host "Found line at index $lineIndex [$($lines[$lineIndex])]"
            
            $leadingSpacesCount = $lines[$lineIndex].Length - $lines[$lineIndex].TrimStart().Length
            $paddedContent = @{ label = "PaddedContent"; expression = { " " * $leadingSpacesCount + $_ } }

            if (-not $replacement.RemovePatternLine) {
                $lineIndex++
            }

            $linesToInsert = [System.Collections.ArrayList]@(($replacementLines | Select-Object $paddedContent | ForEach-Object {$_.PaddedContent.Replace("__EXERCISE_CONTEXT__", $exerciseContext)}))

            $docsIndex = $docs.Add("``````csharp")
            $docs.InsertRange($docs.Count, $linesToInsert)
            $docsIndex = $docs.Add("``````")
            $docsIndex = $docs.Add("")
            $docsIndex = $docs.Add("Solution:")
            $docsIndex = $docs.Add("``````csharp")
            $docs.InsertRange($docs.Count, $lines[$lineIndex..($lineIndex + $removedLinesCount-1)])
            $docsIndex = $docs.Add("``````")

            $lines.RemoveRange($lineIndex, $removedLinesCount)
            $lines.InsertRange($lineIndex, $linesToInsert)

            if ($replacement.ReplaceFirstOccurrenceOnly) {
                break
            }

            $lineIndex = $lines.IndexOf(($lines | Where-Object { $_.Trim() -ieq $startingLinePattern } | Select-Object -First 1))
            Write-Host "Next line index: $lineIndex"
        }

        if ($replacementsCount -eq 0) {
            Write-Host -ForegroundColor Red "ERROR: could not find the specified line pattern."
            $global:errorCount++
        } else {
            Write-Host -ForegroundColor Green "Replaced $replacementsCount occurrences."
        }

        $docsIndex = $docs.Add("")
    }

    Write-Host "Docs count: $($docs.Count)"

    Set-Content -Path $filePath -Value $lines
    Write-Output "Finished changing file $filePath."
}

$fullSolutionPath = "D:\Repos\Solliance-MS-BYOC\src"
$challengesRootPath = "E:\Temp\BYOC\hackathon\solutions"
$errorCount = 0

# --------------------------------------------------------------------
# Create Challenge 6 starter (based on the full solution)
# --------------------------------------------------------------------

$challenge6SourcePath = $fullSolutionPath
$challenge6TargetPath = "$challengesRootPath\challenge-6"
$challenge6SolutionTargetPath = "$challengesRootPath\challenge-6\code\solution"
$challenge6StarterTargetPath = "$challengesRootPath\challenge-6\code\starter"

Copy-SolutionFolders -sourceRelativePath "\" -sourcePath $challenge6SourcePath -targetPath $challenge6SolutionTargetPath
Copy-SolutionFolders -sourceRelativePath "\" -sourcePath $challenge6SourcePath -targetPath $challenge6StarterTargetPath

$challenge6FileChanges = @{
    "Infrastructure\Services\SemanticKernelRAGService.cs" = @(
        @{
            ChallengeNumber = 6
            ExerciseNumber = 1
            ExerciseStepNumber = 1
            StartingLinePattern = "_contextPlugins.AddRange("
            RemovePatternLine = $true
            RemovedLinesCount = 2
            ReplacementLines = @(
                "//--------------------------------------------------------------------------------------------------------",
                "// TODO: __EXERCISE_CONTEXT__",
                "// Add system command plugins to the list of context builder plugins.",
                "// The list of system command plugins is available in _settings.SystemCommandPlugins.",
                "//--------------------------------------------------------------------------------------------------------"
            )
            ReplaceFirstOccurrenceOnly = $true
        },
        @{
            ChallengeNumber = 6
            ExerciseNumber = 2
            ExerciseStepNumber = 1
            StartingLinePattern = "await _semanticCache.Reset();"
            RemovePatternLine = $true
            RemovedLinesCount = 1
            ReplacementLines = @(
                "//--------------------------------------------------------------------------------------------------------",
                "// TODO: __EXERCISE_CONTEXT__",
                "// Invoke the Reset method on the semantic cache service.",
                "// Add a relevant message to the results list to inform the user about the reset.",
                "//--------------------------------------------------------------------------------------------------------"
            )
            ReplaceFirstOccurrenceOnly = $true
        },
        @{
            ChallengeNumber = 6
            ExerciseNumber = 3
            ExerciseStepNumber = 1
            StartingLinePattern = "var similarityScore = await GetSemanticCacheSimilarityScore(userPompt, pluginName);"
            RemovePatternLine = $true
            RemovedLinesCount = 9
            ReplacementLines = @(
                "//--------------------------------------------------------------------------------------------------------",
                "// TODO: __EXERCISE_CONTEXT__",
                "// Invoke the SetMinRelevanceOverride method on the semantic cache service.",
                "// Add a relevant message to the results list to inform the user about the change.",
                "// Compared to handling the cache reset, this exercise is more challenging because you will need to find",
                "// a way to extract the numerical value from the user prompt and set it as the new minimum relevance override.",
                "// Note the GetSemanticCacheSimilarityScore method that you can use to parse the similarity score from the user prompt.",
                "//--------------------------------------------------------------------------------------------------------"
            )
            ReplaceFirstOccurrenceOnly = $true
        },
        @{
            ChallengeNumber = 6
            ExerciseNumber = 3
            ExerciseStepNumber = 2
            StartingLinePattern = "var pluginPrompt = await _systemPromptService.GetPrompt(plugin.PromptName!);"
            RemovePatternLine = $false
            RemovedLinesCount = 21
            ReplacementLines = @(
                "",
                "//--------------------------------------------------------------------------------------------------------",
                "// TODO: __EXERCISE_CONTEXT__",
                "// Check out the prompt that is already configured for the plugin.",
                "// Invoke the prompt to get a structured response that you can then parse to extract the numerical value.",
                "// Note the ParsedSimilarityScore model which is already available and aligned with the prompt structure.",
                "//--------------------------------------------------------------------------------------------------------",
                "return 0.95;"
            )
            ReplaceFirstOccurrenceOnly = $true
        }
    )
}

$description = [System.Collections.ArrayList]@("# Challenge 6", "")

foreach($fileToChange in $challenge6FileChanges.Keys) {
    Change-CodeFile -filePath "$challenge6StarterTargetPath\$fileToChange" -replacements $challenge6FileChanges[$fileToChange] -docs $description
}

Set-Content -Path "$($challenge6TargetPath)\README.md" -Value $description

# --------------------------------------------------------------------
# Create Challenge 5 starter (based on the Challenge 6 starter)
# --------------------------------------------------------------------

$challenge5SourcePath = $challenge6StarterTargetPath
$challenge5TargetPath = "$challengesRootPath\challenge-5"
$challenge5SolutionTargetPath = "$challengesRootPath\challenge-5\code\solution"
$challenge5StarterTargetPath = "$challengesRootPath\challenge-5\code\starter"

Copy-SolutionFolders -sourceRelativePath "\" -sourcePath $challenge5SourcePath -targetPath $challenge5SolutionTargetPath
Copy-SolutionFolders -sourceRelativePath "\" -sourcePath $challenge5SourcePath -targetPath $challenge5StarterTargetPath

$challenge5FileChanges = @{
    "Infrastructure\Services\SemanticKernelRAGService.cs" = @(
        @{
            ChallengeNumber = 5
            ExerciseNumber = 1
            ExerciseStepNumber = 1
            StartingLinePattern = "// This allows us to experiment with different embedding sizes."
            RemovePatternLine = $false
            RemovedLinesCount = 8
            ReplacementLines = @(
                "//--------------------------------------------------------------------------------------------------------",
                "// TODO: __EXERCISE_CONTEXT__",
                "// Initialize the semantic cache service here.",
                "//--------------------------------------------------------------------------------------------------------"
            )
            ReplaceFirstOccurrenceOnly = $true
        },
        @{
            ChallengeNumber = 5
            ExerciseNumber = 2
            ExerciseStepNumber = 1
            StartingLinePattern = "var cacheItem = await _semanticCache.GetCacheItem(userPrompt, messageHistory);"
            RemovePatternLine = $true
            RemovedLinesCount = 13
            ReplacementLines = @(
                "//--------------------------------------------------------------------------------------------------------",
                "// TODO: __EXERCISE_CONTEXT__",
                "// Attempt to retrieve the completion from the semantic cache and return it.",
                "// var cacheItem = ...",
                "// if (!string.IsNullOrEmpty(cacheItem.Completion))",
                "// {",
                "//     return new CompletionResult ...",
                "// }"
                "//--------------------------------------------------------------------------------------------------------"
            )
            ReplaceFirstOccurrenceOnly = $true
        },
        @{
            ChallengeNumber = 5
            ExerciseNumber = 3
            ExerciseStepNumber = 1
            StartingLinePattern = "UserPromptTokens = cacheItem.UserPromptTokens,"
            RemovePatternLine = $true
            RemovedLinesCount = 0
            ReplacementLines = @(
                "UserPromptTokens = 0, // TODO: __EXERCISE_CONTEXT__ Set the user prompt tokens from the cache item."
            )
            ReplaceFirstOccurrenceOnly = $false
        },
        @{
            ChallengeNumber = 5
            ExerciseNumber = 3
            ExerciseStepNumber = 2
            StartingLinePattern = "UserPromptEmbedding = cacheItem.UserPromptEmbedding.ToArray(),"
            RemovePatternLine = $true
            RemovedLinesCount = 0
            ReplacementLines = @(
                "UserPromptEmbedding = [], // TODO: __EXERCISE_CONTEXT__ Set the user prompt embedding from the cache item."
            )
            ReplaceFirstOccurrenceOnly = $false
        },
        @{
            ChallengeNumber = 5
            ExerciseNumber = 4
            ExerciseStepNumber = 1
            StartingLinePattern = "// Add the completion to the semantic memory"
            RemovePatternLine = $false
            RemovedLinesCount = 3
            ReplacementLines = @(
                "//--------------------------------------------------------------------------------------------------------",
                "// TODO: __EXERCISE_CONTEXT__",
                "// Set the completion and the completion tokens count on the cache item and then add then add it to the semantic memory.",
                "//--------------------------------------------------------------------------------------------------------"
            )
            ReplaceFirstOccurrenceOnly = $true
        }
    )
    "Infrastructure\Services\SemanticCacheService.cs" = @(
        @{
            ChallengeNumber = 5
            ExerciseNumber = 5
            ExerciseStepNumber = 1
            StartingLinePattern = "var similarity = 1 - Distance.Cosine(cacheItem.UserPromptEmbedding.ToArray(), userMessageHistory.Last().Vector!);"
            RemovePatternLine = $true
            RemovedLinesCount = 10
            ReplacementLines = @(
                "//--------------------------------------------------------------------------------------------------------",
                "// TODO: __EXERCISE_CONTEXT__",
                "// Handle the particular case when the user asks the same question (or a very similar one) as the previous one.",
                "// Calculate the similarity between cacheItem.UserPromptEmbedding and userMessageHistory.Last().Vector.",
                "// If the similarity is above a certain threshold, return the cache item ensuring you update ConversationContext, ConversationContextTokens, Completion, and CompletionTokens."
                "//--------------------------------------------------------------------------------------------------------"
            )
            ReplaceFirstOccurrenceOnly = $true
        }
    )
}

$description = [System.Collections.ArrayList]@("# Challenge 5", "")

foreach($fileToChange in $challenge5FileChanges.Keys) {
    Change-CodeFile -filePath "$challenge5StarterTargetPath\$fileToChange" -replacements $challenge5FileChanges[$fileToChange] -docs $description
}

Set-Content -Path "$($challenge5TargetPath)\README.md" -Value $description

# --------------------------------------------------------------------
# Create Challenge 4 starter (based on the Challenge 5 starter)
# --------------------------------------------------------------------

$challenge4SourcePath = $challenge5StarterTargetPath
$challenge4TargetPath = "$challengesRootPath\challenge-4"
$challenge4SolutionTargetPath = "$challengesRootPath\challenge-4\code\solution"
$challenge4StarterTargetPath = "$challengesRootPath\challenge-4\code\starter"

Copy-SolutionFolders -sourceRelativePath "\" -sourcePath $challenge4SourcePath -targetPath $challenge4SolutionTargetPath
Copy-SolutionFolders -sourceRelativePath "\" -sourcePath $challenge4SourcePath -targetPath $challenge4StarterTargetPath

$challenge4FileChanges = @{
    "Infrastructure\Services\SemanticKernelRAGService.cs" = @(
        @{
            ChallengeNumber = 4
            ExerciseNumber = 1
            ExerciseStepNumber = 1
            StartingLinePattern = "_prompt = await _systemPromptService.GetPrompt(_settings.OpenAI.ChatCompletionPromptName);"
            RemovePatternLine = $false
            RemovedLinesCount = 0
            ReplacementLines = @(
                "",
                "//--------------------------------------------------------------------------------------------------------",
                "// TODO: __EXERCISE_CONTEXT__",
                "// Analyze the implementation of the ISystemPromptService interface (see the line above).",
                "// Locate the definition of the system prompt used for chat completion and analyze its structure.",
                "// Change the system prompt to experiment the implications in the chat completion process.",
                "//--------------------------------------------------------------------------------------------------------",
                ""
            )
            ReplaceFirstOccurrenceOnly = $true
        },
        @{
            ChallengeNumber = 4
            ExerciseNumber = 2
            ExerciseStepNumber = 1
            StartingLinePattern = "_contextSelectorPrompt = await _systemPromptService.GetPrompt(_settings.OpenAI.ContextSelectorPromptName);"
            RemovePatternLine = $false
            RemovedLinesCount = 0
            ReplacementLines = @(
                "",
                "//--------------------------------------------------------------------------------------------------------",
                "// TODO: __EXERCISE_CONTEXT__",
                "// Locate the definition of the system prompt used to select the plugins",
                "// that will be used to build the context for the completion request (see the line above).",
                "// Change the system prompt to experiment the implications in the chat completion process.",
                "//--------------------------------------------------------------------------------------------------------",
                ""
            )
            ReplaceFirstOccurrenceOnly = $true
        },
        @{
            ChallengeNumber = 4
            ExerciseNumber = 3
            ExerciseStepNumber = 1
            StartingLinePattern = "_logger.LogInformation(""Semantic Kernel RAG service initialized."");"
            RemovePatternLine = $false
            RemovedLinesCount = 0
            ReplacementLines = @(
                "",
                "//--------------------------------------------------------------------------------------------------------",
                "// TODO: __EXERCISE_CONTEXT__",
                "// Attempt to ask questions that would reveal the instructions from the",
                "// system prompt used for chat completion and the context selector prompt.",
                "// Improve the prompts with additional instructions to avoid revealing the instructions.",
                "//--------------------------------------------------------------------------------------------------------"
            )
            ReplaceFirstOccurrenceOnly = $true
        }
    )
}

$description = [System.Collections.ArrayList]@("# Challenge 4", "")

foreach ($fileToChange in $challenge4FileChanges.Keys) {
    Change-CodeFile -filePath "$challenge4StarterTargetPath\$fileToChange" -replacements $challenge4FileChanges[$fileToChange] -docs $description
}

Set-Content -Path "$($challenge4TargetPath)\README.md" -Value $description

# --------------------------------------------------------------------
# Create Challenge 3 starter (based on the Challenge 4 starter)
# --------------------------------------------------------------------

$challenge3SourcePath = $challenge4StarterTargetPath
$challenge3TargetPath = "$challengesRootPath\challenge-3"
$challenge3SolutionTargetPath = "$challengesRootPath\challenge-3\code\solution"
$challenge3StarterTargetPath = "$challengesRootPath\challenge-3\code\starter"

Copy-SolutionFolders -sourceRelativePath "\" -sourcePath $challenge3SourcePath -targetPath $challenge3SolutionTargetPath
Copy-SolutionFolders -sourceRelativePath "\" -sourcePath $challenge3SourcePath -targetPath $challenge3StarterTargetPath

$challenge3FileChanges = @{
    "Infrastructure\Services\SemanticKernelRAGService.cs" = @(
        @{
            ChallengeNumber = 3
            ExerciseNumber = 1
            ExerciseStepNumber = 1
            StartingLinePattern = "var promptFilter = new DefaultPromptFilter();"
            RemovePatternLine = $true
            RemovedLinesCount = 1
            ReplacementLines = @(
                "//--------------------------------------------------------------------------------------------------------",
                "// TODO: __EXERCISE_CONTEXT__",
                "// Attach an IPromptRenderFilter to the Semantic Kernel kernel.",
                "// This will allow you to intercept the rendered prompts in their final form (before submission to the Large Language Model).",
                "// Note that the DefaultPromptFilter is a good starting point to implement a prompt filter.",
                "//--------------------------------------------------------------------------------------------------------"
            )
            ReplaceFirstOccurrenceOnly = $true
        },
        @{
            ChallengeNumber = 3
            ExerciseNumber = 1
            ExerciseStepNumber = 2
            StartingLinePattern = "RenderedPrompt = promptFilter.RenderedPrompt,"
            RemovePatternLine = $true
            RemovedLinesCount = 0
            ReplacementLines = @(
                "RenderedPrompt = string.Empty, // TODO: __EXERCISE_CONTEXT__ Retrieve the rendered prompt via the prompt filter."
            )
            ReplaceFirstOccurrenceOnly = $false
        },
        @{
            ChallengeNumber = 3
            ExerciseNumber = 3
            ExerciseStepNumber = 1
            StartingLinePattern = "// Note that the DefaultPromptFilter is a good starting point to implement a prompt filter."
            RemovePatternLine = $false
            RemovedLinesCount = 1
            ReplacementLines = @(
                "//--------------------------------------------------------------------------------------------------------",
                "",
                "//--------------------------------------------------------------------------------------------------------",
                "// TODO: __EXERCISE_CONTEXT__",
                "// Attach an IFunctionInvocationFilter to the Semantic Kernel kernel.",
                "// This will allow you to intercept the function calling happening behind the scenes.",
                "// Note that you will need to write your own implementation class.",
                "//--------------------------------------------------------------------------------------------------------"
            )
            ReplaceFirstOccurrenceOnly = $true
        }
    )
    "Infrastructure\Services\DefaultPromptFilter.cs" = @(
        @{
            ChallengeNumber = 3
            ExerciseNumber = 2
            ExerciseStepNumber = 1
            StartingLinePattern = "public string RenderedPrompt => _renderedPrompt;"
            RemovePatternLine = $true
            RemovedLinesCount = 8
            ReplacementLines = @(
                "//--------------------------------------------------------------------------------------------------------",
                "// TODO: __EXERCISE_CONTEXT__ Define public properties to expose the intercepted values.",
                "//--------------------------------------------------------------------------------------------------------"
            )
        },
        @{
            ChallengeNumber = 3
            ExerciseNumber = 2
            ExerciseStepNumber = 2
            StartingLinePattern = "_pluginName = context.Function?.PluginName ?? string.Empty;"
            RemovePatternLine = $true
            RemovedLinesCount = 5
            ReplacementLines = @(
                "//--------------------------------------------------------------------------------------------------------",
                "// TODO: __EXERCISE_CONTEXT__ Implement the handler to intercept prompt rendering values.",
                "//--------------------------------------------------------------------------------------------------------",
                "await Task.CompletedTask;"
            )
        }
    )
}

$description = [System.Collections.ArrayList]@("# Challenge 3", "")

foreach ($fileToChange in $challenge3FileChanges.Keys) {
    Change-CodeFile -filePath "$challenge3StarterTargetPath\$fileToChange" -replacements $challenge3FileChanges[$fileToChange] -docs $description
}

Set-Content -Path "$($challenge3TargetPath)\README.md" -Value $description

# --------------------------------------------------------------------
# Create Challenge 2 starter (based on the Challenge 3 starter)
# --------------------------------------------------------------------

$challenge2SourcePath = $challenge3StarterTargetPath
$challenge2TargetPath = "$challengesRootPath\challenge-2"
$challenge2SolutionTargetPath = "$challengesRootPath\challenge-2\code\solution"
$challenge2StarterTargetPath = "$challengesRootPath\challenge-2\code\starter"

Copy-SolutionFolders -sourceRelativePath "\" -sourcePath $challenge2SourcePath -targetPath $challenge2SolutionTargetPath
Copy-SolutionFolders -sourceRelativePath "\" -sourcePath $challenge2SourcePath -targetPath $challenge2StarterTargetPath

$challenge2FileChanges = @{
    "Infrastructure\Services\SemanticKernelRAGService.cs" = @(
        @{
            ChallengeNumber = 2
            ExerciseNumber = 1
            ExerciseStepNumber = 1
            StartingLinePattern = "_semanticKernel = builder.Build();"
            RemovePatternLine = $true
            RemovedLinesCount = 0
            ReplacementLines = @(
                "//--------------------------------------------------------------------------------------------------------",
                "// TODO: __EXERCISE_CONTEXT__",
                "// Explore setting up a Semantic Kernel kernel.",
                "// Explore the use of completion services in the kernel (see the lines above).",
                "// Explore the setup for the Azure OpenAI-based chat completion service.",
                "//--------------------------------------------------------------------------------------------------------",
                "_semanticKernel = builder.Build();"
            )
            ReplaceFirstOccurrenceOnly = $true
        },
        @{
            ChallengeNumber = 2
            ExerciseNumber = 2
            ExerciseStepNumber = 1
            StartingLinePattern = "_semanticKernel.ImportPluginFromObject(_kmContextPlugin);"
            RemovePatternLine = $true
            RemovedLinesCount = 0
            ReplacementLines = @(
                "//--------------------------------------------------------------------------------------------------------",
                "// TODO: __EXERCISE_CONTEXT__",
                "// Explore importing plugins into a Semantic Kernel kernel.",
                "// Explore the implementation of the KnowledgeManagementContextPlugin plugin.",
                "//--------------------------------------------------------------------------------------------------------",
                "_semanticKernel.ImportPluginFromObject(_kmContextPlugin);"
            )
            ReplaceFirstOccurrenceOnly = $true
        },
        @{
            ChallengeNumber = 2
            ExerciseNumber = 3
            ExerciseStepNumber = 1
            StartingLinePattern = "_semanticKernel.ImportPluginFromObject(_listPlugin);"
            RemovePatternLine = $true
            RemovedLinesCount = 0
            ReplacementLines = @(
                "//--------------------------------------------------------------------------------------------------------",
                "// TODO: __EXERCISE_CONTEXT__",
                "// Explore importing plugins into a Semantic Kernel kernel.",
                "// Explore the implementation of the ContextPluginsListPlugin plugin.",
                "//--------------------------------------------------------------------------------------------------------",
                "_semanticKernel.ImportPluginFromObject(_listPlugin);"
            )
            ReplaceFirstOccurrenceOnly = $true
        },
        @{
            ChallengeNumber = 2
            ExerciseNumber = 4
            ExerciseStepNumber = 1
            StartingLinePattern = "var memoryStore = new VectorMemoryStore("
            RemovePatternLine = $true
            RemovedLinesCount = 0
            ReplacementLines = @(
                "//--------------------------------------------------------------------------------------------------------",
                "// TODO: __EXERCISE_CONTEXT__",
                "// Explore using vector stores with a Semantic Kernel kernel.",
                "// Explore the implementation of the VectorMemoryStore class which enables us to use multiple memory store",
                "// implementations provided by Semantic Kernel.",
                "//--------------------------------------------------------------------------------------------------------",
                "var memoryStore = new VectorMemoryStore("
            )
            ReplaceFirstOccurrenceOnly = $true
        },
        @{
            ChallengeNumber = 2
            ExerciseNumber = 5
            ExerciseStepNumber = 1
            StartingLinePattern = "new AzureCosmosDBNoSQLMemoryStore("
            RemovePatternLine = $true
            RemovedLinesCount = 0
            ReplacementLines = @(
                "//--------------------------------------------------------------------------------------------------------",
                "// TODO: __EXERCISE_CONTEXT__",
                "// Explore the CosmosDB memory store implementation from Semantic Kernel.",
                "//--------------------------------------------------------------------------------------------------------",
                "new AzureCosmosDBNoSQLMemoryStore("
            )
            ReplaceFirstOccurrenceOnly = $true
        },
        @{
            ChallengeNumber = 2
            ExerciseNumber = 6
            ExerciseStepNumber = 1
            StartingLinePattern = "new AzureOpenAITextEmbeddingGenerationService("
            RemovePatternLine = $true
            RemovedLinesCount = 0
            ReplacementLines = @(
                "//--------------------------------------------------------------------------------------------------------",
                "// TODO: __EXERCISE_CONTEXT__",
                "// Explore the use of text embedding services in the kernel.",
                "// Explore the setup for the Azure OpenAI-based text embedding service.",
                "//--------------------------------------------------------------------------------------------------------",
                "new AzureOpenAITextEmbeddingGenerationService("
            )
            ReplaceFirstOccurrenceOnly = $true
        },
        @{
            ChallengeNumber = 2
            ExerciseNumber = 7
            ExerciseStepNumber = 1
            StartingLinePattern = "_contextPlugins.Add(new MemoryStoreContextPlugin("
            RemovePatternLine = $true
            RemovedLinesCount = 0
            ReplacementLines = @(
                "",
                "//--------------------------------------------------------------------------------------------------------",
                "// TODO: __EXERCISE_CONTEXT__",
                "// Explore importing plugins into a Semantic Kernel kernel.",
                "// Explore the implementation of the MemoryStoreContextPlugin plugin.",
                "//--------------------------------------------------------------------------------------------------------",
                "_contextPlugins.Add(new MemoryStoreContextPlugin("
            )
            ReplaceFirstOccurrenceOnly = $true
        }
    )
}

$description = [System.Collections.ArrayList]@("# Challenge 2", "")

foreach ($fileToChange in $challenge2FileChanges.Keys) {
    Change-CodeFile -filePath "$challenge2StarterTargetPath\$fileToChange" -replacements $challenge2FileChanges[$fileToChange] -docs $description
}

Set-Content -Path "$($challenge2TargetPath)\README.md" -Value $description

write-host -ForegroundColor (($errorCount -eq 0) ? "Green" : "Red") "Challenge solutions created with $errorCount errors."

