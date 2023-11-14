# **`Suse Linux Enterprise based Ironic Python Agent proof of concept`**

## **`Abbreviations`**

- DIB: Openstack Disk Image Builder
- IPA: Ironic Python Agent
- dev-env: refers to metal3-dev-env repository

## **`Related documentations`**

- [DIB](https://docs.openstack.org/diskimage-builder/latest/)
- [DIB custom elements](https://opendev.org/openstack/diskimage-builder/src/branch/master/doc/source/developer/developing_elements.rst)
- [IPA](https://docs.openstack.org//ironic-python-agent/latest/doc-ironic-python-agent.pdf)

## **`Related repositories`**

- [IPA](https://opendev.org/openstack/ironic-python-agent)
- [ironic-lib](https://opendev.org/openstack/ironic-python-agent)
- [DIB](https://opendev.org/openstack/diskimage-builder)
- [IPA-BUILDER](https://opendev.org/openstack/ironic-python-agent-builder)
- [openstack/requirements](https://opendev.org/openstack/ironic-python-agent-builder)
- [metal3-dev-env](https://github.com/metal3-io/metal3-dev-env)

## **`Motivation`**

After multiple attempts and discussion with the `Openstack-Ironic community` it
was determined that there is no willingness in the Ironic community to maintain
support for SLES image building either in IPA builder or in DIB.

## **`Scope of the repo`**

The repo provides a shell script that governs the IPA build process and a
collection of custom made DIB elements that provide the SLES specific build
actions for DIB. Although there exists an `IPA builder` project that builds on
top of DIB and provides custom elements to build the IPA ram disk, it was
decided to use DIB with some custom elements to remove dependency on
`IPA builder` as it doesn't support SLES based images anyways.

**NOTE:** The workflow expects SLES evaluation images by default for example
 `SLES15-SP4-Minimal-VM.x86_64-OpenStack-Cloud-GM.qcow2` as a base image for
IPA and installs additional distribution packages from
`SLE-15-SP4-Full-x86_64-GM-Media1.iso`. During the build process the custom
elements use the repositories from `SLE-15-SP4-Full-x86_64-GM-Media1.iso`
in order to avoid any potential issue that might arise from the fact that using
remote repositories would require registration but there was no available
documentation about the effect of continuously re-registration of a SLES image
as the image building process would require such action. Building from
disk images also looked like more reliable way because the trial period for
accessing the upstream repositories was short.

## **`Flow of the builder script`**

### **`Environment variables`**

The first section of the build script is the definition of
`Repository configuration options` that specifies the git repository addresses
and git references for `IPA, ironic-lib, opensiht/requirements` and
`metal3-dev-env`. `IPA, ironic-lib, opensiht/requirements` repositories are
installed from source during IPA's build process and metal3-dev-env is cloned
after the build process ended in case testing is enabled.

The second set of environment variables that are named
`General environment variables` are responsible for the following
configurations:

```bash
CURRENT_SCRIPT_DIR # location of the build script
IPA_BUILD_WORKSPACE # by default the whole building process happens in /tmp/dib
IPA_IMAGE_NAME # configure the name of the final IPA image
IPA_IMAGE_TAR # same as above but with tar extension
IPA_BASE_OS # in DIB base OS is configurable but in the curret case it is "sles"
IRONIC_SIZE_LIMIT_MB # the final IPA tar can't exceed this size
DEV_ENV_REPO_LOCATION # location where the script clones the dev-env to
ENABLE_BOOTSTRAP_TEST # used to do some minimal integration testing to see
                      # whether the new IPA does at least inspect and provision
                      # when it is used in dev-env
QUIET_CLEANUP         # option to turn on and off the output of the make clean
                      # commands that are used to clean the test environment
ENABLE_DEV_USER_PASS # Adds a user to the IPA image who has password-less sudo
                     # rights and can log in with a password
DIB_DEV_USER_AUTHORIZED_KEYS # Path to the a ssh key on the build host that
                             # will be copied to to the IPA image and it will
                             # be used as the public key for devuser ssh access
```

### **`Workspace preparation`**

After the general environment variables have been set, the builder script will
install some packages required to use python virtual environment and qemu image
tools. After the packages are installed the script will create the working
directory for the whole build process and it will also install DIB in a python
virtual environment in the same directory and the script will also activate
the virtual environment. The directory specified as the `IPA_BUILD_WORKSPACE`
will be cleaned on every execution of the wrapper script to ensure that
the image is being built in a clean environment.

### **`Using DIB specific parameters`**

The parameterization happens in two parts the first part is to export environment
variables that are prefixed with the `DIB` substring. Using environment variables
prefixed with the `DIB` substring is an expected way for DIB elements to handle
configuration variables coming from outside of the element's own code.

Variables in use:

```bash
DIB_REPOLOCATION_ironic_python_agent # Configure DIB to pull the IPA source
                                     # from specified fork
DIB_REPOREF_requirements # configure what git reference of
                         # `openstack/requirements` repo to use
DIB_REPOREF_ironic_python_agent # configure what git reference of the specified
                                # IPA repo to use
DIB_REPOREF_ironic_lib # configure what git reference of the specified
                       # ironic-lib repo to use
-- Optional variables used by the  `dev-user` element --
DIB_DEV_USER_USERNAME # create a user on the IPA image with this name
DIB_DEV_USER_PWDLESS_SUDO # give password-less sudo right to user yes/no
DIB_DEV_USER_AUTHORIZED_KEYS # use the specified ssh key for authentication for
                             # the new user
DIB_DEV_USER_PASSWORD # use the specified password for authentication for the
                      # new user
DIB_INSTALLTYPE_pip_and_virtualenv # install pip and virtual environment from
                                   # package or source

-- Non prefixed variables --
ELEMENTS_PATH # Provide path(s) of the custom elements for DIB
ADDITIONAL_IPA_KERNEL_MODULES # List of additional kernel modules that should
                              # be loaded during boot separated by space, this
                              # list is used by the custom element named
                              # ipa-modprobe
```

After the DIB variables are exported the next step is to execute the image
building process via DIB by executing the `disk-image-create` command. The
command takes command-line arguments that specify what elements to use from the
default DIB elements and from the custom elements and the resulting image name
is also provided here. After the image building has finished the python virtual
environment is disabled.

### **`Finalizing the build`**

After the build process has completed the build script will copy the results
(kernel + initramfs) into a tar file and it will check the size of the tar file
to verify that it does not exceed the size limit specified in the
`IRONIC_SIZE_LIMIT_MB` environment variable.

### **`Optional test`**

There is a possibility as a last step in the image building script to test the
newly built IPA image in the `metal3-dev-env` if the `ENABLE_BOOTSTRAP_TEST`
variable is set to true.

## `Custom elements`

Most of the custom elements provided as part of the repo are modified versions
of elements from either `DIB` or `IPA image builder`. There are also
dependencies between the custom elements of the repo and upstream elements that
are part of DIB.

The following upstream elements are used as dependencies in the repo:

- [dhcp-all-interfaces](https://opendev.org/openstack/diskimage-builder/src/branch/master/diskimage_builder/elements/dhcp-all-interfaces)
- [ibft-interfaces](https://opendev.org/openstack/diskimage-builder/src/branch/master/diskimage_builder/elements/ibft-interfaces)
- [install-static](https://opendev.org/openstack/diskimage-builder/src/branch/master/diskimage_builder/elements/install-static)
- [source-repositories](https://opendev.org/openstack/diskimage-builder/src/branch/master/diskimage_builder/elements/source-repositories)
- [no-final-image](https://opendev.org/openstack/diskimage-builder/src/branch/master/diskimage_builder/elements/no-final-image)
- [runtime-ssh-host-keys](https://opendev.org/openstack/diskimage-builder/src/branch/master/diskimage_builder/elements/runtime-ssh-host-keys)
- [selinux-permissive](https://opendev.org/openstack/diskimage-builder/src/branch/master/diskimage_builder/elements/selinux-permissive)
- [cache-url](https://opendev.org/openstack/diskimage-builder/src/branch/master/diskimage_builder/elements/cache-url)
- [sysprep](https://opendev.org/openstack/diskimage-builder/src/branch/master/diskimage_builder/elements/sysprep)
- [devuser](https://opendev.org/openstack/diskimage-builder/src/branch/master/diskimage_builder/elements/devuser)

There are also further elements used as dependencies by the upstream elements:

- [dib-init-system](https://opendev.org/openstack/diskimage-builder/src/branch/master/diskimage_builder/elements/dib-init-system)
- [package-installs](https://opendev.org/openstack/diskimage-builder/src/branch/master/diskimage_builder/elements/package-installs)
- [pkg-map](https://opendev.org/openstack/diskimage-builder/src/branch/master/diskimage_builder/elements/pkg-map)
- [manifests](https://opendev.org/openstack/diskimage-builder/src/branch/master/diskimage_builder/elements/manifests)

**Note** Upstream elements can change with time

**Note** `package-installs`, `pkg-map` and the custom element `zypper-config`
provide the functionality for upstream elements to install distribution
packages on `SLES`. These elements could be used to provide mapped package
installs for the custom elements but there were issues experienced with using
mapped package installation in the `SLES` custom elements and also package
mapping is not needed in the repo as it supports only a single distribution.

It is a goal of the repo to minimize the dependency between upstream elements
and custom elements to avoid incompatibility issues as `SLES` is not supported
upstream.

The flow package installation for upstream elements works the following way:

Custom element `zypper-config` configures zypper and installs a
`install-packages` script to the image that will be used by `package-installs`
elements to run zypper installation commands for packages that were mapped as
packages of the `suse` distribution family by the `pkg-map` element.

The aforementioned way of package installation is the standard in upstream DIB
as `pkg-map` combined with `package-installs` elements facilitate a
distribution independent installation functionality. There is an important
environment variable that might be confusing called `DISTRO_NAME` that is used
to configure `pkg-map` to map package names correctly even though the value of
the variable is `opensuse`. If the value of `DISTRO_NAME` is `opensuse` it
tells `pkg-map` to map package names according to the `suse` distribution
family mappings. Package names in the `suse` distribution family mappings for
the upstream elements match the `SLES`.

### **`sles (based on DIB's Centos element)`**

The `sles` element is responsible for preparing the root file system of the IPA
image. The element extracts a root file system from the SLES base image, sets
the legacy and EFI boot configuration and mounts the
`SLE-15-SP4-Full-x86_64-GM-Media1.iso` into the `$TARGET_ROOT/mnt/repos`
location to enable package installation via zypper during the build process.

The directory path on the host system that contains SLES images used by this
element can be specified via the `DIB_SLES_OFFLINE_TARGET_DIR` variable.
Other SLES base and repository image specific variables can be found in the
`environment.d/10-sles-distro-name.bash` script of the `sles` element. The
default value for `DIB_SLES_OFFLINE_TARGET_DIR` is `$HOME/sles_images`.

**NOTE** User has to make sure the SLES images are downloaded to the correct
directory and they are named correctly before the build process is initiated.

All the variables with the `DIB_SLES_*` prefix are used to specify the path
to the images.

`DISTRO_NAME` variable is used mainly by upstream DIB elements in order to
decide what dependency packages to install. The `DISTRO_NAME`'s value is
`opensuse` because the upstream elements have no knowledge of using `SLES` so
to guide the upstream elements to use zypper for package installation the only
option is to tell them that OpenSuse is the distribution in use and then they
can use zypper correctly.

`DIB_INIT_SYSTEM` will specify that the init system used for the IPA is
`systemd`.

`DIB_OFFLINE` is used to determine whether the build process will use local base
and repository images or it will pull the base image from some remote location
and install the packages from upstream repositories. At the moment only offline
build mode is implemented and there is no support for using remote rpm
repositories.

### **`sles-ipa-install (based on IPA builder's ironic-python-agent-ramdisk)`**

This element installs the IPA python application from source and also installs
SLES distribution packages that are requirements of IPA. This element also
installs `ironic-lib` and the `openstack/requirements` python libraries from
source. The element also executes additional configuration tasks related to
systemd service configuration, firmware cleaning, IPA rescue mode configuration
and certificate installation.

The IPA, ironic-lib and requirements repositories are cloned by DIB's
`source-repositories` element then all 3 of them are installed during DIB's
`install stage` via the `ipa_builder_elements/sles-ipa-install/install.d/ironic-python-agent-ramdisk-source-install/60-ironic-python-agent-ramdisk-install`
script. IPA systemd service configuration and IPA configuration files can be
also found in the directory where the `60-ironic-python-agent-ramdisk-install`
script is.

Beyond installing the `ironic-python-agent`, `ironic-lib` and
`openstack/requirements` this element does the following:

- Installs the `dhcp-all-interfaces` so the node, upon booting, attempts to
  obtain an IP address on all available network interfaces.
- Disables the `iptables` service on systemd based systems.
- Installs packages required for the operation of the ironic-python-agent:
   `qemu-utils` `parted` `hdparm` `util-linux` `genisoimage`
- When installing from source, `python-dev` and `gcc` are also installed
  in order to support source based installation of ironic-python-agent and its
  dependencies.
- Install the certificate if any, which is set to the environment variable
  `DIB_IPA_CERT` for validating the authenticity by ironic-python-agent. The
  certificate can be self-signed certificate or CA certificate.
- Compresses initramfs with command specified in environment variable
  `DIB_IPA_COMPRESS_CMD`, which is `gzip` by default. This command should
  listen for raw data from stdin and write compressed data to stdout. Command
  can be with arguments.
- Configures rescue mode if `DIB_IPA_ENABLE_RESCUE` is not set to `false`.

**note**
   Using the ram disk will require at least 1.5GB of RAM

### **`sles-ipa-ramdisk-base`**

(based on IPA builder's ironic-python-agent-ramdisk)

This is a base element for ironic ram disks. It does not install anything, just
takes the prepared images and extract kernel/ramdisk from it.

`Configurable Environment Variables`

- `DIB_IPA_COMPRESS_COMMAND` defaults to `gzip`, may be set to any valid
  compression program usable for an initramfs.
- `DIB_IPA_MINIMAL_PRUNE` defaults to `0` (false). If set to `1`, will skip
  most ramdisk size optimizations. This may be helpful for use of packages
  with IPA that require otherwise-pruned directories or files.

### **`sles-ipa-tls (based on IPA builder's ironic-python-agent-tls)`**

This element is used to enable TLS support on IPA API either with self
signed certificates or with pre made regular certificates.

If enabled without any environment variables set to modify configuration,
this element will enable TLS API support in IPA with a self-signed certificate
and key created at build time.

Optionally, custom SSL certificate and key can be provided, and optionally
ca, via the following environment variables. They should be set to an
accessible path on the build systems filesystem. If set, they will be copied
into the built ramdisk, and IPA will be configured to use them.

`Configurable Environment Variables`

- `DIB_IPA_CERT_FILE` should point to the TLS certificate for ramdisk use.
- `DIB_IPA_KEY_FILE` should point to the private key matching
  `DIB_IPA_CERT_FILE`.

If having a certificate generated, it can be configured how it's generated:

- `DIB_IPA_CERT_HOSTNAME` the CN for the generated
  certificate. Defaults to "ipa-ramdisk.example.com".
- `DIB_IPA_CERT_EXPIRATION` expiration, in days, for the certificate.
  Defaults to 1095 (three years).

Note that the certificates generated by this element are self-signed, and
any nodes using them will need to set `agent_verify_ca=False` in `driver_info`.

This element can also configure client certificate validation in IPA. If it is
needed to validate client certificates, set `DIB_IPA_CA_FILE` to a CA file's
path that the IPA client connections will be validated against. This CA file
will be copied into the built ramdisk, and IPA will be configured to use it.

### **`sles-extra-hardware (based on IPA builder's extra-hardware)`**

This element adds the [hardware](https://pypi.python.org/pypi/hardware)
python package to the IPA ramdisk. It also installs
several package dependencies of the `hardware` module.

The `hardware` package provides improved hardware introspection capabilities
and supports benchmarking. This functionality may be enabled by adding the
`extra-hardware` collector in the `[DEFAULT] inspection_collectors` option
or the `ipa-inspection-collectors` kernel command line argument.

The following environment variables may be set to configure the element when
doing a source-based installation:

- `DIB_IPA_HARDWARE_PACKAGE` the full `hardware` Python package descriptor
  to use. If unset, `DIB_IPA_HARDWARE_VERSION` will be used.

- `DIB_IPA_HARDWARE_VERSION` the version of the `hardware` package to
  install when `DIB_IPA_HARDWARE_PACKAGE` is unset. If unset, the latest
  version will be installed.

### **`sles-zypper (based on DIB's zypper element)`**

This element provides some customizations for zypper. It works in a very
similar way as the yum element does for yum based distributions in DIB.

Zypper is reconfigured so that it keeps downloaded packages cached outside of
the build chroot so that they can be reused by subsequent image builds. The
cache increases image building speed when building multiple images, especially
on slow connections.  This is more effective than using an HTTP proxy for
caching packages since the download servers will often redirect clients to
different mirrors.

**Note:** Currently the `sles-zypper` element's pre-install step is used to
configure the python version and the zypper repositories for the IPA image and
the related logic is implemented in
`sles-zypper/pre-install.d/01-zypper-keep-packages`.
The aforementioned script could be a good place to implement remote zypper
repository registration without much hassle in case it is required. The element
also installs the `install-packages` script to provide `SLES` distribution
support (technically implements an "interface" in bash ) for
`package-installs` element that installs dependencies for upstream elements.

### **`ipa-module-autoload`**

The only purpose of this module is to add linux kernel module names to the
`/etc/modules-load.d/load.conf` in the image. Modules that are added to the
module `autoload` configuration will load automatically on IPA boot. The list
of packages to load can be set as a space separated list named
`DIB_ADDITIONAL_IPA_KERNEL_MODULES`.

### **`ipa-add-buildinfo`**

This element is just a space holder element that inserts a build date to the
`/buildinfo.txt`. The element can be expanded in scope in the future as users
see fit.

## Additional notes

- As DIB mounts a copy of the base image during the IPA build process, there
  might be a situation in case of a failure when the image is not unmounted
  correctly so it worth to check from time to time whether there is unknown
  mounts present on the machine that has their mount point under /tmp.
