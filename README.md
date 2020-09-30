# ecosis-deployment
EcoSIS Web Applications Deployment

# Contents
  - [Application Setup](#application-setup)
  - [Development deployments](#development-deployments)
  - [Production Deployments](#production-deployments)
  - [Local Development](#local-development)
    - [Setup](#local-development---setup)
    - [Dev Cycle](#local-development---dev-cycle)
  - [Usage](#usage)
    - [Env File](#env-file)
    - [Endpoints](#endpoints)
      - [Public Endpoints](#public-endpoints)
      - [Private Endpoints](#private-endpoints)

# Application Setup

The EcoSIS applications are a series of git repositories containing one or more Docker containers.  A build of the EcoSIS application is defined in the `config.sh` file where `*_TAG` variables define which git repository tag/branches or docker image tag (for external images) will be used for the `APP_VERSION` of the application.

Each branch of this deployment repository corresponds to a deployed application environment; main = prod, dev = dev, etc.

To run the the application, simply clone this repository at the tag/branch you wish to run, setup the .env file, and start.

 - `git clone https://github.com/cstars/ecosis-deployment`
 - `git checkout [APP_VERSION]`
 - Setup .env file [see below](#env-file)
 - Start docker-compose
   `docker-compose up`

# Development deployments

Development deployments, any non-master branch (production) deployment, have relaxed rules for their deployment definition (`config.sh`) to facilitate rapid builds and testing.

  - When starting work on a new feature you can set `APP_VERSION` to either: the branch name or a version up tick with a suffix of `-dev`, `-rc1`, `-rc2`, etc.  ex: `APP_VERSION=v1.0.1-dev`.  You do not need to update this tag while you make updates and redeployments.  The `APP_VERSION` tag can stay fixed throughout the feature development process.
  - `*_TAG` variables can point at branches (instead of tags) in development branches (ONLY!).  This allows you to create builds of the latest code without having to create new 'versions' very time you want to test.
  - Branches `master`, `rc`, and `dev` will automatically build new images when this repository is pushed to GitHub.  However, in development you may wish to build without committing the repo.  For that case, simply run `./cmds/submit.sh` to start a new build.
  - IMPORTANT.  When you are ready to commit changes, run `./cmds/generate-deployment-files.sh` to build a new docker-compose.yml file(s) and k8s files (TODO) of this deployment setup.  Then you can commit your changes.


# Production Deployments

Production deployments follow strict rules.  Please follow below.

  - merge the `rc` branch into `master`
    - `git checkout master`
    - `git merge rc`
  - Uptick `APP_VERSION` in `config.sh` to the new production version of the application.  There should be no suffix.
  - Generate new docker-compose file
    - `./cmds/generate-deployment-files.sh`
  - Commit and push changes to this repository.  Set the commit message as the version tag if you have nothing better to say
    - `git add --all`
    - `git commit -m "[APP_VERSION]"`
    - `git push`
  - On push, all production images will be automatically built
  - Tag the commit with the `APP_VERSION`.
    - `git tag [APP_VERSION]`
    - `git push origin [APP_VERSION]`
  - It is very important that `APP_VERSION` in `config.sh` and the tag match.

Done!

# Local Development

Local development should be thought of has completely seperate from production or development deployments.  Local development images should NEVER leave your machine.  To protect agains local images deployed elsewhere, they will always be tagged with 'local-dev'.  To deploy development images to a server use the [Development Deployment](#development-deployments) described above.

## Local Development - Setup

To get started with local development, do the following:

  - Clone this repository
    - `git clone https://github.com/cstars/ecosis-deployment`
  - Checkout the branch you wish to work on, ex:
    - `git checkout dev`
    - `git checkout -b [my-new-feature]`
  - In the same **parent** folder at you cloned `ecosis-deployment`, clone all git repositories for this deployment.  They are defined in `config.sh` in the `Repositories` section.  
  IMPORATANT: Make sure you checkout to the branches you wish to work on for each repository.
  - Setup the `./repositories` folder.  There is a helper script for this:
    - `./cmds/init-local-dev.sh`
  - Create the docker-compose.yaml file:
    - `./cmds/generate-deployment-files.sh`
    - Note: the local development folder (ecosis-local-dev) is ignored from git.  you can make changes at will, though these changes will be overwritten every time you run `generate-deployment-files.sh`.  To makes permanent changes you will need to update the `./templates/local-dev.yaml` file
  - create your .env file [see below](#env-file)

## Local Development - Dev Cycle

  - Make your code changes in your local repositories
    - See note below, you do not need to rebuild images on every change.  Just certain changes.
  - Build the `local-dev` tagged images:
    - `./cmds/build-local-dev.sh`
  - Start the local environment:
    - `cd ecosis-local-dev; docker-compose up`


Local development notes.

   - Most containers have a commented out `command: bash -c "tail -f /dev/null"` in the `./ecosis-local-dev/docker-compose.yaml`.  You can uncomment this so the container starts without running the default process. Then you can bash onto container to for faster start/stop of server to see changes. ex:
     - uncomment `command: bash -c "tail -f /dev/null"` under the `search` service
     - `docker-compose exec search bash`
     - `node server.js` - starts the server
     - `ctrl+c` - stops the server
  - Code directories are mounted as volumes so changes to your host filesystem are reflected in container.  However, changes to application packages (ex: package.json) will require rebuild of images (`./cmds/build-local-dev.sh`)

# Usage

## Env File

Here are the .env file parameters.

  - `SERVER_URL` Public url for search system.  Defaults to http://localhost:3000
  TODO


There are additional config variables you an use see in the main [config.js](https://github.com/cstars/ecosis/blob/master/lib/config.js) file.  However it is not recommend to change them unless you know what you are doing.