# Galette Docker project
Building and maintaining this project is solely about the containerization of the finished Galette packages. If you want to contribute to Galette itself, take a look [here](https://galette.eu/site/contribute/). 

## Updating to next Galette version
If you just want to upgrade to the next version of Galette, all you need to do is change the version number in the Dockerfile: `ARG GALETTE_VERSION=<version>`. You might also need to update the plugin versions: `ARG PLUGIN_<plugin name>_VERSION=<version>`. 

You can also provide these arguments as a build-args (see [Building the docker image with another version of PHP and/or Galette](#building-the-docker-image-with-another-version-of-php-andor-galette)).

After this, you _should_ of course build and test like described in [Building and testing locally](#building-and-testing-locally). But you can also commit the change, merge it to master and start a new release in GitHub. The github action [build and publish](./.github/workflows/docker-build-and-publish.yml), will build and publish the image, when a new release is published.

In steps:
1. Create a new branch or fork 
2. Update `Dockerfile` with new version(s)
3. [Build and test locally](#building-and-testing-locally) - _yeah, you really should do this ;)_
4. Make a pull request and await approval if you can't approve yourself.
    - Normal contributers cannot proceed past this step. The next step requires elevated access to the github repository. So these steps are intended for the maintainer(s) of the project.
5. Once merged, click Releases in Github
6. Click "Draft new Release" button
7. Select "Choose a tag" and type a version number equal to the Galette version in the `Dockerfile`. Click "Create new tag: <version> on publish".
8. Update the description (copy paste from the previous release) and update latest changes, using the "Generate Release Notes" button
9. Click publish release
10. The github action [build and publish](./.github/workflows/docker-build-and-publish.yml), will build and publish the image automatically.
    - Note: [build and publish](./.github/workflows/docker-build-and-publish.yml) uses the username and a personal access token from a docker-hub user with access to the [galette organisation](https://hub.docker.com/orgs/galette/members) on dockerhub. These are both stored as secrets in Github. These tokens should be the current maintainer's.

### Setting up an access token to deploy to docker hub
Prerequisite is that you are co-admin of galette docker on docker hub: https://hub.docker.com/r/galette/galette
1. Log in to docker hub
2. Access your account settings (upper right corner, then "Account settings")
3. In the navigation menu to the left click "Personal access tokens"
4. Click "Generate new token"
5. Give your token a name, e.g. `galette github actions auto-push`
6. Select Expiration date
7. Select "Read, Write, Delete"
8. Click "Generate"
9. Copy your personal access token (if you don't you have to restart this guide)
10. Go to https://github.com/galette/docker/settings/secrets/actions
11. Click New repository secret
12. Name `DOCKERHUB_TOKEN`
13. Secret must be the code you copied from step 9.
14. Click New repository secret
15. Name `DOCKERHUB_User`
16. Secret must be your docker hub username

## Building and testing locally
### Prerequisites
- `docker` is installed in your development environment.
- `dockerd` the docker deamon is installed (and [started](https://docs.docker.com/config/daemon/start/))
- `buildx` is installed in your development environment.

Although it's possible to build packages without `dockerd` running, using [`buildah`](https://buildah.io/), the focus here is on [`buildx`](https://docs.docker.com/reference/cli/docker/buildx/). You're welcome to contribute with instructions for `buildah`.

### Linting
1. Start the docker daemon if it's not already started: `sudo dockerd`
2. Run hadolint (containerized): `docker run --rm -i -v ./.config/hadolint.yml:/.config/hadolint.yaml hadolint/hadolint < Dockerfile`
3. Fix errors and warnings or add them to ignore list of the [hadolint configuration file](./.config/hadolint.yml) if there is a good reason for that. Read more [here](https://github.com/hadolint/hadolint).

### Building the docker image locally
1. Start the docker daemon if it's not already started: `sudo dockerd`
2. Run the build command: `docker buildx build --platform linux/amd64 -t galette-local --load .`
    * replace the platform (`linux/amd64`) if you're building on another platform
    * replace `galette-local` with any name you would like to give your local image
    * `--load` loads the image into your local docker, so you can use it as a container image.

#### Building the docker image with another version of PHP and/or Galette
Follow the instructions above, but add any or both of these build args to the build command: `PHP_VERSION` and/or `GALETTE_VERSION`. For example:

    ```
    docker buildx build --platform linux/amd64 -t galette-local-special \
    --build-arg PHP_VERSION=8.2 \
    --build-arg GALETTE_VERSION=1.0.4 \
    --load .
    ```

#### Building the docker image with Galette pre-releases
- Follow the instructions above, but override the two build args: `MAIN_PACKAGE_URL` and `GALETTE_RELEASE`. For example:
    ```
    docker buildx build --platform linux/amd64 -t galette-local-prerelease \
    --build-arg MAIN_PACKAGE_URL=https://galette.eu/download/dev/ \
    --build-arg GALETTE_RELEASE=galette-1.1.0-rc1-20240508-95bbbc2ede \
    --load .
    ```
- If you want to add nightly official plugin releases, follow the instructions above, but add which release you want for each plugin as builds args, e.g. So for eample:
    ```
    docker buildx build --platform linux/amd64 -t galette-local-prerelease \
    --build-arg MAIN_PACKAGE_URL=https://galette.eu/download/dev/ \
    --build-arg GALETTE_RELEASE=galette-1.1.0-rc1-20240508-95bbbc2ede \
    --build-arg PLUGIN_AUTO_VERSION=dev \
    --build-arg PLUGIN_EVENTS_VERSION=dev \
    --build-arg PLUGIN_FULLCARD_VERSION=dev \
    --build-arg PLUGIN_MAPS_VERSION=dev \
    --build-arg PLUGIN_OBJECTSLEND_VERSION=dev \
    --build-arg PLUGIN_PAYPAL_VERSION=dev \
    --build-arg PLUGIN_ACTIVITIES_VERSION=dev \
    --load .
    ```

### Building for multiple architecures locally
1. Start the docker daemon if it's not already started: `sudo dockerd`
2. Create a builder-image `docker buildx create --name mybuilder --use --bootstrap` (see "Building with Buildx" [here](https://www.docker.com/blog/how-to-rapidly-build-multi-architecture-images-with-buildx/) for more details)
3. Run the build command: `docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 -t galette-local .`
    * replace `galette-local` with any name you would like to give your local image
    * NOTE: The build process is significantly longer than just building for your local architecture.

### Running the docker image locally
1. Follow the same steps as in [How to use this image](./README.md#How-to-use-this-image), replacing the image name `galette/galette:latest` with your local container name, e.g. `galette-local`.
