<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

This project implements automated email donation acknowledgements similar to Salesforce NPSP. Use Apex, triggers, and LWC best practices.

Your audience is experienced software developers who are new to Salesforce development. Provide clear, concise instructions and examples.

Use the newer 'sf' CLI commands instead of the older 'sfdx' commands

When you add a new file always do the following:

1. Add the file to the appropriate directory in the project.
1. Add a metadata .xml file if applicable.
1. Update the package manifest file (package.xml) to include the new file.

Any time you add or update a metadata .xml file, be sure that all tags are supported by the current version of the Salesforce API. Ensure that there is a comment to the top of the metatdata file that includes a link to the documentation for the .xml file format.

Never remove TODO comments unless you have completed the task.

--source-path is not an option in the 'sf' CLI command, so do not use it. Use --dir-path instead.

Test script is located at scripts/run_all_tests.sh - This test script does not run code coverage, it only runs tests.

All deploys are done using the manifest file (package.xml) or individual files.

Only test code coverage at the end of the development process, not during development.

I review your code changes in detail only after all tests pass. Make sure to get confirmation before moving on to the next step.

Run code coverage tests synchronously, not asynchronously. Use the `--synchronous` flag with the `sf apex test run` command. Don't use the --wait flag for code coverage reports.

Never use emoji in commit messages or comments. It's ok to use emoji in the Readme file.

When renaming files use 'git mv' to preserve history

tail apex logs with `sf apex log tail --debug-level SFDC_DevConsole`

When doing dependency injection, use mutable instance variables instead of constructor injection when possible.

When we are preparing a plan and make changes to it, always respond with a new plan that includes the changes. Do not just say "I will update the plan" or "I will make the changes". Always provide a complete plan with the changes included.

When creating test mocks, always include configuration and verification helper methods (such as setSuccessful, setFailure, setPartialFailure, reset, and verify\* methods) to make tests expressive, maintainable, and robust, following the pattern used in MockEmailService.

Maintain existing whitespace between blocks when editing code to ensure readability and consistency

Maintain existing comments when editing code unless you have changed the functionality of the code. If you change the functionality, update the comment to reflect the new behavior.
