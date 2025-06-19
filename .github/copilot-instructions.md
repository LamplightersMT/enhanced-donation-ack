<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

This project implements automated email donation acknowledgements similar to Salesforce NPSP. Use Apex, triggers, and LWC best practices.
Ensure all emails are stored as EmailMessage records

Your audience is experienced software developers who are new to Salesforce development. Provide clear, concise instructions and examples.

Triggers must be implemented in the TDTM framework, described here: https://help.salesforce.com/s/articleView?id=sfdo.eda_deploy_apex_tdtm.htm&type=5

Use the newer 'sf' CLI commands instead of the older 'sfdx' commands

Use 4 spaces for indentation, no tabs. ALWAYS USE 4 SPACES FOR INDENTATION. NEVER USE 2 SPACES FOR INDENTATION.

Any time you add a new file, add an appropriate metadata .xml file if applicable.

Any time you add or update a metadata .xml file, be sure that all tags are supported by the current version of the Salesforce API. Ensure that there is a comment to the top of the metatdata file that includes a link to the documentation for the .xml file format.

Never remove TODO comments unless you have completed the task.

--source-path is not an option in the 'sf' CLI command, so do not use it. Use --dir-path instead.
