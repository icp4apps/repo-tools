# repo-tools
This repository contains a selection of tools and configuration templates to support the creation and lifecycle of a Stack Hub repository.

## repo-tools structure
The repo-tools repository contains four folders:
1) config - This folder is where the configuration file that defines the content of the Stack Hub repository will be placed.
2) scripts - This folder contains the scripts that will compose the Stack Hub repository
3) example_config - This folder contains sample configuration files.
4) templates - This folder contains template configuration files that can be used as a starting point for a Stack Hub repositories configuration.

## Stack Hub Repository
A Stack Hub repository is a collection of meta-data for a group of stacks. Stack Hub repositories support Appsody and Devfile development stacks.

### Creating a Stack Hub repository
repo-tools is a template repository and should be used as the base for your Stack Hub repository. To create a Stack Hub repository follow the [GitHub documentation](https://docs.github.com/en/github/creating-cloning-and-archiving-repositories/creating-a-repository-from-a-template) using the [icp4apps/repo-tools](https://github.com/icp4apps/repo-tools) repository as the template.

## Defining your configuration
Before building a Stack Hub repository you need to create the configuration that identifies what the repository will include.

### Including Appsody stacks
Appsody stacks can be included in your Stack Hub by adding a configuration file with the following configuration to your Stack Hubs config folder:

```
# Template for repo-tools configuration
name: <Repository name>
description: <Repository description> 
version: <Repository version>
stacks:
  - name: <Repository index name>
    repos:
      - url: <Reference to index file>
      exclude:
          - <stack name>
        include:
          - <stack name>
image-org: <Organisation containing images within registry>
image-registry: <Image registry hosting images>
nginx-image-name: <Image name for the generated nginx image, defaults to repo-index>
```
where:  
`name:` is an identifier for this particular configuration  
`description:` is a description of the configuration  
`version:` is a version for the configuration, may align with a repository release.  
`stacks: - name:` is the name of a repository to be built.  
`stacks:   repos:` is an array of urls to stack indexes / repositories to be included in this repository index  
`stacks:   repos:    -url:    exclude:` is an array of stack names to exclude from the refrenced stack repository. This field is optional and should be left blank if filtering is not required.  
`stacks:   repos:    -url:    include:` is an array of stack names to include from the refrenced stack repository. This field is optional and should be left blank if filtering is not required.  
`image-org:` is the name of the organisation within the image registry which will store the docker images for included stacks. This field is optional and controls the behaviour of the repository build, further details are avalable below.  
`image-registry:` is the url of the image registry being used to store stack docker images. This field is optional and controls the behaviour of the repository build, further details are avalable below.  
`nginx-image-name:` is the name assigned to the generated nginx image, defaults to repo-index.   

**NOTE -** `exclude`/`include` are mutually exclusive, if both fields are populated an error will be thrown.

#### Composition of public stacks / repositories.
If the stacks and repositories you are including are all publically available then repo-tools can simply compose a new repository file that uses references to the existing stack asset locations. When this type of build is required simply leave the `image-org` and `image-registry` fields of your configuration empty. The composed repository files will be stored in the `assets` folder generated when the tools are run.

#### Packaging private stacks / repositories.
If your stacks / repositories are hosted in a private environment that your deployment environment and tools cannot access, such as GitHub Enterprise,  you can leverage the repo-tools to create an NGINX image that can serve the assets required to make use of your stacks from within the deployment environment. When this type of build is required configure the `image-org` field to be the name of the org within your target registry and the `image-registry` field to be the URL of the actual registry the images will be placed in. You can optionally configure the name of the resulting image using the `nginx-image-name` field. Once run your local docker registry will contain the generated NGINX image which can be pushed to the registry your deployment environment will access. Once deployed the image will server the repository index files that were created as part of the build.

You can find an [example configuration](https://github.com/appsody/repo-tools/blob/master/example_config/example_repo_config_appsody_stacks.yaml) within the example_config folder.

### Including devfile stacks
Devfile stacks can be included in your Stack Hub by adding a configuration file with the following configuration to your Stack Hubs config folder:

```
# Configuration for CP4A application stack CRD creation
name: <Configuration name> 
description: <Configuration description>
version: <Configuration version>
stack_groups:
  - name: <CRD collection name>
    repos:
      - url: <Reference to devfile repository index file>
        exclude:
          - <stack name>
        include:
          - <stack name>
```
where:  
`name:` is an identifier for this particular configuration  
`description:` is a description of the configuration  
`version:` is a version for the configuration, may align with a repository release.  
`stack_groups: - name:` is the name of a stack group to be built.  
`stacks:   repos:` is an array of urls to devfile registries containing devfile stacks to be included in this stack group.  
`stacks:   repos:    -url:    exclude:` is an array of stack names to exclude from the refrenced devfile registry. This field is optional and should be left blank if filtering is not required.  
`stacks:   repos:    -url:    include:` is an array of stack names to include from the refrenced devfile registry. This field is optional and should be left blank if filtering is not required.  

**NOTE -** `exclude`/`include` are mutually exclusive, if both fields are populated an error will be thrown.

## Building the Stack Hub
The stack hub can be built manually or via a CI pipeline such as Travis.

### Building the Stack Hub manually
When building the Stack Hub manually any generated index files or CRD groupings will be written to the '`assets` folder at the bsase directory of the Stack Hub repository.

To generate assets for your stack hub you need to execute the relevant build script passing the name of your configuration file. To generate assets for both types of configuration run both build scripts.

If building from an Appsody configuration:
1) Create your Appsody configuration file and place it in the config folder.
2) From the base folder of the repository run the build tool using the command `./scripts/hub_build.sh <config file>`. You do not need to specify the path to the file.

If building from a Devfile configuration:
1) Create your Devfile configuration file and place it in the config folder.
2) From the base folder of the repository run the build tool using the command `./scripts/crd_build.sh <config file>`. You do not need to specify the path to the file.

#### Releasing a manually built stack hub
Once you have your generated assets you can host them in a location where they can be accessed by anyone that requires access. If your build was configured to generate an NGINX image then you will need to push it to the image registry it was built for.

### Build and release the Stack Hub using Travis CI
repo-tools includes a template configuration file for use with Travis CI [here](./templates/template_travis_ci.yml). To use the template follow these steps:

#### Copy and update the template
1) Copy the `template_travis_ci.yml` to a temporary location and name it `.travis.yml`.
2) You need to update the file as follows:
    - Uncomment any required build scripts. Use `hub_build.sh` for Appsody configuration and `crd_build.sh` for devfile configuration.
    - Replace `<appsody config>` and `<odo config>` with the names of the Apssody and Odo configuration files as required.
    - Replace `<git org>/<git repository>` with the GitHub organisation and repository name for the Stack Hub, eg, `icp4apps/StackHub`.

#### Enable Travis on your repository
Follow the [instructions](https://docs.travis-ci.com/user/tutorial/) for enabling Travis CI on the Stack Hub repository.

#### Configuring a PAT to allow Travis to create a Github release
Configure an access token so Travis can access the Stack Hub repository and create releases using the guidance [here](https://docs.travis-ci.com/user/deployment/releases/).

#### Create a release build
Once Travis is configured the Stack Hub can be released by adding a tag to the source. You can do this through the Git CLI or GitHub website. Details on creating a release can be found [here](https://docs.github.com/en/github/administering-a-repository/managing-releases-in-a-repository). If you wish to use the git CLI then refer to the following [reference](https://git-scm.com/book/en/v2/Git-Basics-Tagging), builds will run when the tag is pushed.
