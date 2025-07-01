# yaai_ui - ABAP AI User Interface
This repository contains the user interface components for the `ABAP AI Tools`, designed to enhance interaction with the core functionalities.

**See it in Action** 😊
<p>
  <video src="docs/videos/abap_ai_chat.mp4" width="1000" autoplay loop muted playsinline>
    Your browser does not support the video tag.
  </video>
</p>

## Installation
You can install the `ABAP AI User Interface` into your SAP system using `abapGit`. Follow the steps below:

## Prerequisites
 - **ABAP AI Tools**: The `ABAP AI Tools` (https://github.com/christianjianelli/yaai) must be installed in your SAP system before proceeding with the UI installation.
 - **abapGit**: Ensure that `abapGit` is installed and configured in your ABAP system. If not, you can find the latest version and installation instructions on the official abapGit website: https://docs.abapgit.org/
 - **Developer Access**: You need appropriate developer authorizations in your ABAP system to import objects.

## Installation Steps

 1 - **Open abapGit**: In your SAP GUI, execute transaction `ZABAPGIT` (or the equivalent transaction code you have set up for abapGit).

 2 - **Add Online Repository**:
   - Click on the `+` button (Add Online Repo) or select "New Online" from the menu.

 3 - **Enter Repository URL**:
   - In the "URL" field, paste the URL of this GitHub repository: `https://github.com/christianjianelli/yaai_ui`
   - For the **Package**, we recommend creating a new package called `YAAI_UI`. Remember to assign it to a transport request if necessary.
   - Click "OK" or press Enter.

 4 - **Clone Repository**:
   - `abapGit` will display the repository details. Review the objects that will be imported.
   - Click the "Clone" button (often represented by a green download icon).

 5 - **Activate Objects**:
   - Once the cloning process is complete, `abapGit` will list the imported objects.
   - Activate any inactive objects if prompted.

 6 - **Verify Installation**:
   - After activation, all the `ABAP AI User Interface` objects (classes, programs, etc.) will be available in your specified package. You can verify this by checking transaction `SE80` for the package you used.

You have now successfully installed the `ABAP AI User Interface!`

## User Interface Components

Explore these components to enhance your workflow with ABAP AI Tools.

- **Chat Interface**: Engage in conversational AI interactions directly within your SAP system.

    [<img src="docs/images/abap_ai_ui_chat.png" alt="ABAP AI UI Chat" height="200px">](docs/images/abap_ai_ui_chat.png)

  <br>

- **Code Assistant**: Access AI-powered code suggestions and assistance for ABAP development.

    [<img src="docs/images/yaai_ui_code_assist.png" alt="ABAP AI UI Code Assistant" height="200px">](docs/images/yaai_ui_code_assist.png)
