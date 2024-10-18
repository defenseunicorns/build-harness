# Build Harness: A Docker Image for Customizable and Repeatable Build and Test Environments

Build Harness is a Docker image, loaded with an array of tools, built to transform the way you approach your development workflows. The aim? To create repeatable build and test environments, wherever you need them - from setting up a fresh laptop for a new team member to integrating into a Continuous Integration (CI) workflow pipeline.

## Getting Started

### Using Build Harness

Getting started with Build Harness is as easy as running `docker run`. Here's an example from the perspective of how somebody might use it in a setting where a Golang application is being developed.

```
# Running this will drop you into a shell inside Build Harness, with your current working directory mounted into the image.
docker run -it --rm -v "${PWD}:/app" --workdir "/app" ghcr.io/defenseunicorns/build-harness/build-harness:<version> bash

# Running this will run the 'go test' command, then exit
docker run -it --rm -v "${PWD}:/app" --workdir "/app" ghcr.io/defenseunicorns/build-harness/build-harness:<version> bash -c 'go test ./...'
```

A more transportable alternative might be to wrap the command in a Makefile target:

```
test:
    docker run -it --rm -v "${PWD}:/app" --workdir "/app" ghcr.io/defenseunicorns/build-harness/build-harness:<version> bash -c 'go test ./...'
```

Doing so would allow running the same command (`make test`) in your local environment, dev environment, or CI workflow. This results in more  repeatable environments. Stay tuned for a separate blog post that talks about this concept.

To get a better idea of what it looks like to use Build Harness operationally, take a look at [this repo](https://github.com/defenseunicorns/terraform-aws-vpc) where it is used. This pattern uses a Makefile to wrap actions that utilize Build Harness to run `make test` or `make pre-commit-all`.

### Contributing to Build Harness

See [CONTRIBUTING.md](CONTRIBUTING.md) for more information on how to contribute to Build Harness.

## Why Repeatable Environments?

In an increasingly complex and distributed development landscape, the ability to have consistent and repeatable build and test environments has become a non-negotiable requirement. A common baseline ensures code behaves the same way across all settings, eliminating the infamous "it works on my machine" scenarios. Having a consistent environment reduces the time spent troubleshooting environment-specific issues and allows teams to focus on what really matters - building great software.

## Why Have Pre-Installed Tools?

One of the key features of Build Harness that sets it apart is the pre-installation of a host of useful tools. At first glance, this may seem like a simple convenience - a nice-to-have rather than a necessity. However, this feature brings tremendous value to any automated workflow, impacting both efficiency and reliability.

### Speeding Up Your Workflows

One of the most immediate and noticeable benefits is the reduction in the setup time for each job in your automated workflows. Without pre-installed tools, each job or pipeline run would need to start by installing the necessary tools before it can start the actual task at hand. These installation steps can take significant time, especially when dealing with larger tools or complex setups. By having the tools pre-installed, Build Harness allows your jobs to hit the ground running, focusing immediately on the task at hand rather than setting up. This can considerably speed up your overall workflow run times, especially for workflows that run frequently or have many jobs.

### Increasing Reliability

Pre-installing tools also significantly boosts the reliability of your workflows. With traditional setup steps, there is always a risk that a tool installation fails due to network issues, changes in the tool's distribution, or other unforeseen problems. Such failures can cause your entire workflow to fail, even if the code changes being tested are perfectly fine. By using Build Harness with its pre-installed tools, you eliminate this risk. The tools are already there, ready to use, ensuring your workflows are more robust and less likely to fail for reasons outside of your code.

### Simplifying your Workflow Definitions

Having pre-installed tools also simplifies your workflow definitions. Without them, each job needs to start with a series of setup steps to install the necessary tools. This can make your workflow definitions longer, more complex, and harder to read. With Build Harness, you can eliminate these setup steps from your workflows, making them simpler and more focused on the tasks they are meant to perform.

## Enter Build Harness

Harnessing the power of Docker, Build Harness encapsulates all necessary tools into one portable and consistent image. The result is an environment that is the same on every machine, every time. It works seamlessly on a new hire's laptop, on your CI/CD pipeline, or anywhere else Docker runs.

## Customizing Build Harness

One size rarely fits all in software development. Different projects may require different tool versions to work correctly. That's why Build Harness comes equipped with the [asdf version manager](https://asdf-vm.com/).

With asdf, Build Harness supports the addition of a `.tool-versions` file to your project, empowering you to declare custom versions of the tools installed on the image. This feature ensures that your project will always use the right tools in the right versions, eliminating conflicts and version-related issues. Now you don't need to choose between the benefits of a consistent environment and the need for customization.

One downside to this approach is that you much run `asdf install` each time to install the versions of any tools that aren't already present in the Build Harness. Our recommendation is to stick with the latest versions of the tools, as there are security benefits as well to keep up with software updates. If there are reasons that prevent you from staying on the latest version, one option would be to maintain your own customized Build Harness. Here's an example Dockerfile of how that might look:

```
FROM ghcr.io/defenseunicorns/build-harness/build-harness:<version>
COPY .tool-versions /root/.tool-versions
RUN asdf install
```

## Frequently Asked Questions

**Q: How big is Build Harness?**

A: It's definitely not small, but our goal is to keep it small enough such that it provides a net improvement in developer quality of life. If it starts getting too big we are already thinking of ways to be able to pivot to allow for smaller images. Our GitHub Actions Caches pages are reporting that Build Harness currently takes up about 710MB of cache space.

**Q: What tools are installed in Build Harness?**

A: Build Harness contains many of the tools that Unicorns use every day, like tools that work with Kubernetes (Helm, Flux, K9s, etc), Infrastructure as Code (Terraform, terraform-docs, checkov, etc), App development (Golang, Python, etc), debugging tools (curl, jq, netcat, etc), and Unicorn tools (Zarf, etc). See the full list by opening up the [.tool-versions](.tool-versions) file and the [Dockerfile](Dockerfile).

Ideally we want any tool that any Unicorn uses in their build and test workflows to be present in the Build Harness. There may come a day where that is not feasible for all of them to be in one Docker image, but we believe that day isn't here yet. If and when it comes, we will evaluate how to support the concept of a Build Harness with a collection of images, one for each major type of work that we do. Our guiding principle is that any given project/repo only needs to use ONE Build Harness. Having to use multiple Docker images is clunky and complex, and we want to avoid that.

**Q: What is the strategy for deciding which versions of the tools are installed in the Build Harness?**

A: Our objective is that each new version of the Build Harness that is published contains the latest version of each tool at the time that it was published. If customization is needed a `.tool-versions` file may be used to specify the version of any tool that is needed. Run `asdf install` to install the custom versions that are specified in the `.tool-versions` file.

**Q: How will Build Harness speed up my workflows if the pipeline has to download it every time?**

A: Caching. The recommended way to use Build Harness is to set it up such that your CI engine caches the image between runs. It is way faster to pull an artifact from the cache than it is to download something from the internet.

Here's an example snippet of a GitHub Action that caches the Build Harness:

```yaml
- name: Init docker cache
  id: init-docker-cache
  uses: actions/cache@v3
  with:
    path: "${{ github.workspace }}/.cache/docker"
    key: "docker|${{ hashFiles('.env') }}"

- name: Docker save build harness
  if: steps.init-docker-cache.outputs.cache-hit != 'true'
  run: |
    make docker-save-build-harness
  shell: bash

- name: Load build harness
  run: |
    make docker-load-build-harness
  shell: bash
```

* this workflow utilizes a `.env` file that contains the version of Build Harness to use. As long as that file stays unchanged across workflow runs the Build Harness will be cached.
* `make docker-save-build-harness` runs `docker pull` and `docker save` to save the image as a tarball
* `make docker-load-build-harness` runs `docker load` to load the tarball into docker.
* Note that `docker-save-build-harness` only gets run if there is no cache hit.

**Q: Who maintains Build Harness?**

A: Defense Unicorns does! /s

Most of the maintenance is done by Andy Roth, Andrew Blanchard, and other members of the Dash Days Testing Team.

**Q: Will Build Harness work on my ARM-based computer?**

A: Yes! We publish both x86_64 and ARM64 architectures. Docker should automatically choose the correct arch to use.

**Q: I use Podman instead of Docker. Will Build Harness work for me?**

A: Likely yes, though we don't "officially" support Podman at this time as we don't include it in our automated testing suite.

**Q: How is Build Harness tested?**

A: Currently we require that each Pull Request runs a workflow that builds the Build Harness successfully before being allowed to merge to main. This is a very lightweight testing strategy currently and there is a lot of room for improvement. We welcome any ideas around how to make the testing more robust.

**Q: Build Harness doesn't have a tool that I need. Can I get it added?**

A: Yes! Please submit a GitHub Issue [here](https://github.com/defenseunicorns/build-harness/issues/new/choose).

**Q: I see that Docker is installed. Isn't that dangerous?**

A: Mounting the Docker Socket is a security risk that requires other mitigations to be in place. See <https://stackoverflow.com/a/41822163>. Doing so will give the container root access to the host machine. No additional security risk is posed if this container is run without mounting the docker socket. It is our belief that this is safe to do on GitHub Actions hosted runners, since it is GitHub's own infrastructure that would be at risk if they didn't mitigate what would otherwise be an incredibly easy to exploit security hole. This is NOT regarded as safe to do on self-hosted runners without having taken some other mitigation step first.
