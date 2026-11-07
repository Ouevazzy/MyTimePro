<!--
{
  "documentType" : "article",
  "framework" : "Updates",
  "identifier" : "/documentation/Updates/FoundationModels",
  "metadataVersion" : "0.1.0",
  "role" : "article",
  "title" : "Foundation Models updates"
}
-->

# Foundation Models updates

Learn about important changes to Foundation Models.

## Overview

Browse notable changes in <doc://com.apple.documentation/documentation/FoundationModels>.

## June 2026

### General

- Build multimodal agentic app experiences by using the
  <doc://com.apple.documentation/documentation/FoundationModels/LanguageModelSession/DynamicProfile> API.
- Use the improved error types, like
  <doc://com.apple.documentation/documentation/FoundationModels/LanguageModelError>
  for model-specific errors, <doc://com.apple.documentation/documentation/FoundationModels/SystemLanguageModel/Error>
  for on-device Apple Foundation model errors, and
  <doc://com.apple.documentation/documentation/FoundationModels/LanguageModelSession/Error>
  for errors related to the session but not the model.

### Models

- Use the latest on-device <doc://com.apple.documentation/documentation/FoundationModels/SystemLanguageModel>
  that follows instructions more accurately and produces better results, including
  in complex scenarios. Because the model changes when a person updates to iOS 27,
  iPadOS 27, macOS 27, and visionOS 27, test your prompts with the new model to
  verify your app’s behavior.
- Adopt the <doc://com.apple.documentation/documentation/FoundationModels/LanguageModel>
  protocol to use any large language model — server or on-device — with the
  Foundation Models framework.
- Use <doc://com.apple.documentation/documentation/FoundationModels/PrivateCloudComputeLanguageModel>
  to access more reasoning capabilities and a larger context size.
- Perform image analysis tasks by including an image in your prompt and using tools
  the <doc://com.apple.documentation/documentation/Vision> framework provides, like
  <doc://com.apple.documentation/documentation/Vision/OCRTool> and
  <doc://com.apple.documentation/documentation/Vision/BarcodeReaderTool>.

### Tool calling

- Control how the model interacts with tools for your request by using
  <doc://com.apple.documentation/documentation/FoundationModels/GenerationOptions/ToolCallingMode-swift.struct>.

### Instruments

- Use the updated
  [Foundation Models instrument](doc://com.apple.documentation/documentation/FoundationModels/analyzing-the-runtime-performance-of-your-foundation-models-app)
  to get detailed insight into the complex workflows you build. The instrument
  provides insight into latency, prompts sent to the model, model output, tools
  and token usage, and so on.

### Open source

- Get the [Foundation Models framework utilities](https://github.com/apple/foundation-models-utilities)
  to access a collection of building blocks to help you explore emerging practices
  in working with large language models.
- Use [CoreAILanguageModel](https://github.com/apple/coreai-models) and
  [MLXLanguageModel](https://github.com/ml-explore/mlx-swift-lm) to integrate
  on-device models with the Foundation Models framework.

## March 2026

- Use the [Foundation Models SDK for Python](https://github.com/apple/python-apple-fm-sdk)
  to access the on-device foundation model at the core of Apple Intelligence.

## February 2026

- Use the latest on-device large language model that improves instruction-following
  and tool-calling abilities. Because the model changes when a person updates to iOS 26.4,
  iPadOS 26.4, macOS 26.4, and visionOS 26.4, test your prompts with the new model
  to verify your app’s behavior. If necessary, update and maintain prompts for each
  model version.
- Reduce the possibility of blocking benign content with improved guardrails
  for <doc://com.apple.documentation/documentation/FoundationModels/SystemLanguageModel>.
- Measure how many tokens your prompt, instructions, or entire session transcript
  uses with <doc://com.apple.documentation/documentation/FoundationModels/SystemLanguageModel/tokenCount(for:)>.
- Use the <doc://com.apple.documentation/documentation/FoundationModels/SystemLanguageModel/contextSize>
  property to get the maximum context size — in tokens — that
  the <doc://com.apple.documentation/documentation/FoundationModels/SystemLanguageModel>
  supports.
- Use the `#Playground` macro in Xcode to view an estimate of the usage of 4,096
  tokens in the available context window. When you run the canvas, the output
  displays Input Token Count and Response Token Count separately.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)