## SilverStripe in a docker container

SilverStripe is an open-source Content Management System (CMS) and a PHP framework for creating and maintaining websites.

This is a base image for easily running SilverStripe without having to install it first, which is a quite time-consuming process when starting from scratch. 

This image includes:
 - nginx v1.6.2
 - php v5.6.22
 - mysql v14.14 (client only) 
 - composer v1.2-dev

And SilverStripe itself of course! You specify SilverStripe version in the tag of the image: e.g. `gambitlabs/silverstripe:3.1` contains the latest patch release for `3.1` (at the time of writing: `3.1.19`)

Now when it's dockerized, it's a perfect deployment solution for applications written for the LEMP stack.

_Note: It isn't production ready (yet!), but perfect for testing._

### Dockerize any SilverStripe site! (Express deployment)

If you download this repo, you're able to convert any SilverStripe project to a docker image (at least, I hope so)

```console
# Assume we are in the home directory, and have one SilverStripe project called my-project.com
$ pwd
/home/user-1
$ ls
my-project.com

# Here we have a SilverStripe version of version 3.x
$ ls my-project.com
assets cms framework your-module some-extension mysite themes __ss_environment.php index.php

# Download the source
$ git clone https://github.com/gambit-labs/silverstripe

# Now we have two folders
$ ls
my-project.com silverstripe
$ cd silverstripe

# Deploy the site locally using docker.
# SITE_DIR = the directory where the source is
# SITE_REPO = the name the docker image should have. In the form docker-user/repository
# SITE_VERSION = the version of the site you have.
# SS_VERSION = the version of SilverStripe you want to use. Available: [3.0, 3.1, 3.2, 3.3, 3.4]
# There are more releases of the Gambit SilverStripe image as well, you may check out Docker Hub for more info
$ make deploy-site-locally SITE_DIR=/home/user-1/my-project.com SITE_REPO=some-docker-hub-id/my-project SITE_VERSION=1.0 SS_VERSION=3.3

# Now, check out http://localhost to browse the site
```

### Wait, what? (Manual steps and explanation)

How did that work? Well, Gambit has released docker base images that includes everything SilverStripe requires to run. 
That makes it possible to run SilverStripe easily on virtually any host that has Docker installed. No more complex, manual SilverStripe installs.

#### Build an Docker image with your source (optional)

The simple, default `mysite` SilverStripe ships with isn't so fun in the long-term, so it's possible to copy in the source of any SilverStripe project as well.
This is made simple by Docker's `ONBUILD` statement.
TL;DR; The only thing you need to do, is to add a `Dockerfile` to the root of your project.

```console
$ pwd
/home/user-1/my-project.com

# Create a Dockerfile with just one statement, FROM.
$ echo "FROM gambitlabs/silverstripe:3.3" > Dockerfile

# And build the image with your site in it
$ docker build -t some-docker-hub-id/my-project:1.0 .
Sending build context to Docker daemon 588.3 kB
Step 1 : FROM gambitlabs/silverstripe:3.3
# Executing 1 build trigger...
Step 1 : ADD . ${SOURCE_DIR}
 ---> 27e0d72e4eff
Removing intermediate container ee0ca15ff66d
Successfully built 27e0d72e4eff
```

Here's really some `ONBUILD` magic. It copies the current directory (your site) into a source directory the base image `gambitlabs/silverstripe` serves from. See the Dockerfile in this project and read the Docker documentation about `ONBUILD` for more information.

Note that `cms`, `framework` and `__ss_environment.php` are _NOT_ used in the container.
If they exist, they're overridden by the official SilverStripe release, and this is what it makes it so easy to switch versions, or even run the same site with 5 different SilverStripe versions on the same host, in different Docker containers.

However, now that you've got your image `some-docker-hub-id/my-project:1.0`, what can you do with it?

First off, SilverStripe needs a database to store things in. Let's start a MariaDB one! (MySQL is also fine)

```console
# This command is a bit complex. First, the content in $() is executed, i.e. docker starts a MariaDB container.
# From that run command, the container id is returned. We're using the container id to link the MariaDB container to the SilverStripe container.
# From the SilverStripe's point of view, the MariaDB database is available at host db, on port 3306.
# We're doing all this without affecting the host at all. The only thing you may want to customize it the port.
# If you want to expose SilverStripe on port 8080 instead, change `-p 80:80` to `-p 8080:80`

# Run MariaDB and SilverStripe. The version may be customized.
docker run -d -p 80:80 \
	--link $(docker run -d -e MYSQL_ROOT_PASSWORD=root mariadb):db \
	-e SS_DATABASE_SERVER=db \
	some-docker-hub-id/my-project:1.0

# Now, check out http://localhost to browse the site
```

One command, `make deploy-site-locally` did all of this for you, automatically. 
But it's recommended to learn how it works and set it up manually.

Also note that we may spin up as many containers (=sites) as we want with this command.
The only thing that then should change is the port that is exposed on host (the first argument to `-p`)

#### Run the site from a mount, without building a custom image

Instead of building a new image with your content, you may just serve the content via a Docker mount.

```console
$ pwd
/home/user-1/my-project.com

# Run MariaDB and SilverStripe. The version may be customized.
docker run -d -p 80:80 \
	--link $(docker run -d -e MYSQL_ROOT_PASSWORD=root mariadb):db \
	-e SS_DATABASE_SERVER=db \
	-v $(pwd):/source \
	gambitlabs/silverstripe:3.3
```

### Options/customization

You may customize the settings in the `__ss_environment.php` file by passing the arguments as `-e` parameters to docker run.

Here are the options and their default values:

Official SS_* variables:
 - `SS_ENVIRONMENT_TYPE=dev`
 - `SS_DATABASE_SERVER=127.0.0.1`
 - `SS_DATABASE_PORT=3306`
 - `SS_DATABASE_USERNAME=root`
 - `SS_DATABASE_PASSWORD=root`
 - `SS_DEFAULT_ADMIN_USERNAME=admin`
 - `SS_DEFAULT_ADMIN_PASSWORD=admin`

Variables customized for this image:
 - `SS_TIMEZONE="Europe/Helsinki"`: The timezone that should be set in php.ini
 - `SS_WEB_HOST=localhost`: The host nginx thinks it is serving on
 - `SS_LISTEN_PORT=80`: The port nginx should serve on

### Development/live mode

By using the method above, the source files of your site aren't modified in any way.

But what if you want to be able to change the source (develop) at the same time you're serving the site?
Enter the development mode!

It's easy, just set `DEV_MODE=1` in the container and mount a path, e.g. `$(pwd)/live` to `/live` in the container.

```console
$ pwd
/home/user-1/my-project.com
$ ls
assets cms framework your-module some-extension mysite themes __ss_environment.php index.php

# Run the image in development mode. The version/port may easily be customized.
docker run -d -p 80:80 \
	--link $(docker run -d -e MYSQL_ROOT_PASSWORD=root mariadb):db \
	-e SS_DATABASE_SERVER=db \
	-e DEV_MODE=1 -v $(pwd)/live \
	-v $(pwd):/source \
	gambitlabs/silverstripe:3.3

# Notice the "live" folder. The files that are served in the docker container are now there, and you may edit them as you want.
# Without touching the source-controlled files in this directory. Perfect!
$ ls
assets cms framework live mysite some-extension themes your-module __ss_environment.php index.php
```

## Deploy to Kubernetes!

By using the Makefile that is included in this repo, it's very easy to deploy your newly-built site to Kubernetes for even more scale!

```console
# Deploy the site to a Kubernetes cluster.
# SITE_DIR = the directory where the source is
# SITE_REPO = the name the docker image should have. In the form docker-user/repository
# SITE_VERSION = the version of the site you have.
# SS_VERSION = the version of SilverStripe you want to use. Available: [3.0, 3.1, 3.2, 3.3, 3.4]
# There are more releases of the Gambit SilverStripe image as well, you may check out Docker Hub for more info
$ make deploy-site-locally SITE_DIR=/home/user-1/my-project.com SITE_REPO=some-docker-hub-id/my-project SITE_VERSION=1.0 SS_VERSION=3.3

$ kubectl get svc my-project -o template --template {{.spec.clusterIP}}
10.0.0.x

# Now you may browse your site on http://10.0.0.x

# To turn it down, run:
$ make deploy-site-k8s SITE_REPO=some-docker-hub-id/my-project SITE_VERSION=1.0
```

## Build the SilverStripe base image

```console
# Variables:
# IMAGE_AUTHOR=gambitlabs, the Docker Hub user the images should be pushed to
# IMAGE_NAME=silverstripe, the image name
# IMAGE_REVISION=1, the revision of the Dockerfile
# VERSIONS="3.4.0 3.3.2 3.2.4 3.1.19 3.0.14", the versions of SilverStripe we want to build
$ ./build-images.sh
```

and if you want to push at the same time:

```console
$ PUSH=1 ./build-images.sh
```

The above command will build the SilverStripe base image for all latest 3.x minor releases.

### License

MIT
