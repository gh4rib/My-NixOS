# 🛡️ NixSec: The Declarative Cybersecurity Analyst Workstation

A production-ready, highly compartmentalized NixOS configuration engineered specifically for cybersecurity analysts, malware researchers, and security engineers.

This configuration transforms a standard laptop into a reproducible, full-stack virtualization lab. By combining the declarative power of NixOS with a massive array of hypervisors, strict kernel hardening, and container runtimes, it enables analysts to simulate complex network topologies, safely detonate malware, and reverse-engineer mobile applications—all from a single, immutable host system.

## 🎯 Why This Exists

Security analysis requires strict isolation and defense-in-depth. Traditional Linux distributions suffer from "dependency rot" when juggling multiple virtualization toolchains, proprietary drivers, and isolated environments, while often leaving the host kernel exposed.

**NixSec** solves this by treating the entire analyst operating system as code. It leverages an Intel/NVIDIA hybrid graphics stack, deploys an entire lab environment natively, and enforces surgical kernel hardening that protects the host OS without breaking your hypervisors.

## 🔐 The Qubes OS Paradigm: Security by Compartmentalization

Inspired by the architecture of **Qubes OS**, NixSec empowers analysts to implement strict security-by-compartmentalization. By utilizing the integrated virtualization stack, you can create multiple, tightly isolated Virtual Machines (VMs) and containers to segregate your digital life.

Analysts can easily separate their personal daily routines, corporate communications, and high-risk malware detonation labs into distinct environments. This paradigm ensures that even if a payload successfully executes within a research VM, your core host system and personal data remain completely protected.

---

## 🛡️ Defense-in-Depth: Host Hardening

To prevent container breakouts and host compromise during malware analysis, this configuration applies strict global security policies that remain fully compatible with your virtualization stack:

* **Memory Sanitization:** Enforces `init_on_alloc=1` and `init_on_free=1` to eliminate use-after-free vulnerabilities and heap data leaks.
* **Information Leak Prevention:** Hides kernel pointers (`kptr_restrict=2`), restricts `dmesg` access, and completely disables unprivileged eBPF execution.
* **Network Stack Lockdown:** Enforces strict Reverse Path Filtering (`rp_filter=1`) to drop spoofed packets and ignores rogue ICMP redirects to prevent the host from being manipulated by simulated network attacks.
* **Exploit Mitigation:** Randomizes kernel stack offsets, shuffles page allocator freelists, and forces Page Table Isolation (PTI).

### ☢️ Advanced Opt-In Hardening (Audience Beware)

NixSec strikes a deliberate balance between defense-in-depth and functional virtualization. Several highly aggressive `sysctl` and kernel parameters frequently found in enterprise hardening guides have been intentionally excluded from the default `configuration.nix` because they will instantly break the virtualization stack.

If you are modifying this configuration for a non-virtualization workload, you may manually opt-in to the following strict protections:

### 1. The Kernel Lockdown Flags
Adding `lockdown=confidentiality` to `boot.kernelParams` or setting `security.lockKernelModules = true` prevents the kernel from loading out-of-tree modules.
* **Why it is disabled:** This permanently breaks proprietary NVIDIA drivers, VMware Workstation, VirtualBox, and Waydroid's Android ashmem integrations.

### 2. User Namespace Restrictions
Setting `kernel.unprivileged_userns_clone = 0` in `sysctl` prevents normal users from creating new namespaces.
* **Why it is disabled:** Modern containerization relies heavily on unprivileged user namespaces. Disabling this completely destroys rootless Podman, Docker, and LXC execution.

### 3. Network Routing Restrictions
Setting `net.ipv4.ip_forward = 0` prevents the Linux host from acting as a router.
* **Why it is disabled:** Incus, Docker, and KVM rely on IP forwarding to provide NAT and bridged internet access to your virtual machines. Disabling this severs your lab's network connections.

### 4. Strict Systemd Sandboxing
While custom host-level scripts should be heavily sandboxed, **do not** apply strict `systemd` isolation (such as `PrivateDevices=true`, `ProtectKernelModules=true`, or `RestrictNamespaces=true`) to hypervisor daemons like `libvirtd`, `incus`, or `docker`. These engines require raw kernel-level privileges to construct hardware overlays for your virtual machines. 

**For custom network-facing scripts on your host, use this baseline systemd hardening template:**
```nix
systemd.services.my-custom-service = {
  serviceConfig = {
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    NoNewPrivileges = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    RestrictNamespaces = true;
    SystemCallArchitectures = "native";
    SystemCallFilter = [ "@system-service" "~@privileged @resources" ];
  };
};
```

### The "Paranoid" Service Blueprint

When you write custom services (e.g., an automated malware fetcher script, a local log parser, or a custom API on your host), you should apply a strict sandbox. `systemd` uses the Linux kernel's cgroups, namespaces, and seccomp filters to achieve this.

Here is an example of how to declare a nearly bulletproof custom service in your `configuration.nix`:

```nix
  # Example: A custom host service restricted to the absolute minimum privileges
  systemd.services.my-secure-daemon = {
    description = "Isolated Analyst Script";
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python /opt/my-script.py";
      
      # --- The Systemd Security Sandbox ---
      
      # 1. File System Isolation
      ProtectSystem = "strict";     # Mounts /, /usr, and /boot as read-only.
      ProtectHome = true;           # Prevents any access to /home, /root, and /run/user.
      PrivateTmp = true;            # Gives the service its own isolated /tmp and /var/tmp.
      ReadWritePaths = [ "/var/log/my-script/" ]; # The ONLY place it can write.

      # 2. Network Isolation (If the script doesn't need internet)
      PrivateNetwork = true;        # Disconnects it from the host network stack (loopback only).

      # 3. Privilege Escalation Prevention
      NoNewPrivileges = true;       # The service and its children cannot gain new privileges (e.g., via setuid).
      ProtectKernelTunables = true; # Mounts /sys and /proc/sys as read-only.
      ProtectKernelModules = true;  # Prevents the service from loading new kernel modules.
      ProtectControlGroups = true;  # Makes the cgroup hierarchies read-only.

      # 4. Capability & Hardware Dropping
      CapabilityBoundingSet = "";   # Drops all root capabilities (like CAP_NET_ADMIN or CAP_SYS_ADMIN).
      PrivateDevices = true;        # Hides physical hardware devices in /dev (exposes only /dev/null, /dev/urandom, etc.).
      
      # 5. Syscall Filtering (Seccomp)
      SystemCallArchitectures = "native";
      SystemCallFilter = [ 
        "@system-service"           # Allows standard service syscalls...
        "~@privileged @resources"   # ...but explicitly blocks privileged and resource-altering syscalls.
      ];
    };
  };

```

### Hardening Existing NixOS Services
You can run ``systemd-analyze security`` to see a beautiful :) evaluation of Linux services against sandboxing and privilege-related settings which generate a security exposure score between 0.0 (most secure) and 10.0 (highly exposed or unsafe for each of the systemd services.

You can dynamically inject these security parameters into services that NixOS creates automatically, without rewriting the entire service file. This is done using `systemd.services.<name>.serviceConfig`.

For example, to harden the `sshd` (OpenSSH) daemon on your host so that even if an authentication bypass occurs, the daemon cannot alter kernel tunables or access device nodes:

```nix
  # Inject strict sandboxing into the native SSH daemon
  systemd.services.sshd.serviceConfig = {
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    PrivateDevices = true;
    NoNewPrivileges = true;
    RestrictRealtime = true;     # Prevents the service from monopolizing CPU scheduling
    RestrictNamespaces = true;   # Prevents the service from creating new namespaces (container breakout mitigation)
  };

```

### The Danger Zone: Virtualization Conflicts

Because you are building a **full-stack virtualization lab**, you must be incredibly careful where you apply `systemd` sandboxing.

**DO NOT apply strict `systemd` hardening to these services:**

* `libvirtd.service` (KVM/QEMU)
* `incus.service`
* `docker.service` / `podman.service`
* `waydroid-container.service`

**Why?** Hypervisors and container runtimes *require* the exact privileges that systemd sandboxing blocks. They need to mount `/dev/net/tun` for bridge networking, they need `CAP_SYS_ADMIN` to create new kernel namespaces for their containers, and they need to load kernel modules (`kvm_intel`, `vhost_net`). If you apply `PrivateDevices = true` or `RestrictNamespaces = true` to Docker or Libvirt, your entire lab will instantly break.

**The Strategy:** Let the hypervisors run with the high privileges they need. Focus your `systemd` host hardening exclusively on **network-facing services** (like SSH, Syncthing, or custom web servers) and **automated parsers** that interact with untrusted malware data on the host.


Please review these links to get some additional information about them: [link1](https://github.com/klaver/sysctl), [link2](https://obscurix.github.io/security/kernel-hardening.html), [link3](https://docs.rockylinux.org/10/guides/security/systemd_hardening/)

---

## 🏗️ The Virtualization Arsenal

This system comes pre-configured with a multi-tiered virtualization stack, allowing you to choose the exact level of isolation required for your threat model:

### 1. Bare-Metal Isolation (Type-1)

* **Xen Hypervisor:** A dedicated boot menu specialisation turns the system into a Xen `Dom0`. By explicitly disabling Type-2 hypervisors and proprietary NVIDIA drivers in this mode, it creates a pristine, highly compartmentalized environment ideal for hypervisor vulnerability research and strict OS isolation.

### 2. High-Performance Hardware Virtualization (Type-2)

* **KVM / QEMU (Libvirt):** The default workhorse for malware detonation and deploying Intrusion Detection Systems (IDS). Pre-configured with TPM 2.0 (swtpm) for testing modern payloads or Secure Boot bypasses.
* **VMware Workstation & VirtualBox:** Natively supported and isolated for analyzing legacy enterprise OVA/OVF templates or running proprietary security appliances.

### 3. High-Density Network Simulation (System Containers)

* **Incus (LXD Fork):** Pre-seeded with a custom `incusbr0` NAT bridge and directory-backed storage. Perfect for spinning up dozens of lightweight Linux nodes to simulate complex topologies with near-zero overhead.
* **LXC / LXCFS:** Core kernel-level isolation for system containers.

### 4. Microservices & Application Security

* **Podman & Docker:** Fully integrated for auditing vulnerable web applications, testing container breakouts, or running isolated forensic tools without root privileges.

### 5. Mobile Emulation

* **Waydroid:** A complete, hardware-accelerated Android environment running natively on Wayland. Designed for dynamic APK analysis and reverse-engineering Android malware.

---

## 💻 Hardware Architecture & Optimization

* **Wayland First:** Fully configured with `xdg-desktop-portal` and Ozone environment variables to enforce native Wayland rendering for modern applications, minimizing the X11 attack surface.
* **NVIDIA PRIME Offload:** Runs the desktop securely on the Intel iGPU to preserve battery life, while exposing the NVIDIA GPU via an explicit offload wrapper. Perfect for executing localized, GPU-accelerated workloads (e.g., Hashcat cracking) only when requested.
* **Legacy Hardware Support:** Explicitly pinned to the `legacy_580` NVIDIA branch and `intel-compute-runtime-legacy1` to ensure perfect OpenCL and CUDA functionality on Gen 10/11 Intel architectures and Maxwell-based GPUs.

---

## 🧠 Specialisations: Tactical Boot Modes

When booting your machine, the Limine bootloader will present several secondary NixOS entries, allowing you to instantly morph your workstation's architecture based on your current mission.

### Mode 1: The Xen "Red Pill" (Type-1 Isolation)

In this mode, the Type-1 Xen Hypervisor takes over the hardware. The proprietary NVIDIA stack is stripped out in favor of the open-source `nouveau` driver, and out-of-tree hypervisors (VMware/VirtualBox) are disabled to prevent kernel module conflicts, leaving you with a pristine `Dom0` for strict compartmentalization research.

### Mode 2: Hardened Kernel Workstation

Reboots the system using the upstream `linuxPackages_hardened` kernel patchset. Because out-of-tree closed-source hypervisors (VMware/VirtualBox) fail to compile against these hardened structures, they are automatically dropped. However, native Type-2 engines (KVM, Incus, Docker, and Podman) remain fully operational, giving you a maximally defensive fortress for detonating highly evasive threats.

---

## 🚀 Deployment Instructions

### 1. Pre-Flight Check (Crucial)

Before deploying this Flake, you **must** update the PCI Bus IDs to match your specific hardware.
Run the following command to find your GPU addresses:

```bash
lspci | grep -i vga

```

Open `configuration.nix` and update the `prime` block, converting the output to Nix format (e.g., `00:02.0` becomes `PCI:0@0:2:0`):

```nix
intelBusId = "PCI:0@0:2:0";
nvidiaBusId = "PCI:1@0:0:0";

```

### 2. Build the System

Apply the configuration to your host:

```bash
sudo nixos-rebuild switch --flake .#nixos

```

### 3. Initialize the Mobile Lab (Waydroid)

Once rebooted into the new configuration, initialize the Android environment with Google Play Services (GAPPS) for dynamic app testing:

```bash
sudo waydroid init -s GAPPS -f

```

---

## ⚡ Custom CachyOS Kernel Integration

Since the popular Chaotic Nyx project was archived, the `xddxdd/nix-cachyos-kernel` repository has become the gold standard for getting highly tuned kernels on NixOS. Because this setup is optimized for CPUs that natively support AVX-512 instructions, compiling the kernel with `x86_64-v4` optimizations yields fantastic performance improvements.

To safely inject these custom kernels without breaking the rest of your system, the configuration splits the process into two parts: adding the Flake input, and defining the boot menu specialisations.

### Step 1: Update `flake.nix` (The Input & Overlay)

You must tell your Nix system where to fetch the CachyOS packages from and apply them as an overlay. Add the `nix-cachyos-kernel` input to your `flake.nix`, ensuring you use the `release` branch to hit the binary cache.

```nix
{
  description = "Whalers0 NixOS System";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11"; 
    
    # 1. Add the xddxdd CachyOS kernel repository
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    nix-cachyos-kernel.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nix-cachyos-kernel, ... }@inputs: {
    nixosConfigurations.whalers0 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # 2. Inject the CachyOS packages via the pinned overlay
        ({ pkgs, ... }: {
          nixpkgs.overlays = [ nix-cachyos-kernel.overlays.pinned ]; 
        })
        
        ./configuration.nix
      ];
    };
  };
}

```

### Step 2: Update `configuration.nix` (The Specialisations)

Now that `pkgs.cachyosKernels` exists in your system, merge your custom boot entries into the existing `specialisation` block at the bottom of your configuration:

```nix
  # --- Boot Specialisations ---
  specialisation = {
    
    # [ ... Xen and Hardened specialisations remain here ... ]

    # CachyOS BORE Scheduler + AVX512 (v4)
    cachyos-bore.configuration = {
      system.nixos.tags = [ "cachyos-bore" ];
      boot.kernelPackages = lib.mkForce pkgs.cachyosKernels.linuxPackages-cachyos-bore-x86_64-v4;
    };

    # CachyOS EEVDF (Latest) + AVX512 (v4)
    cachyos-latest-lto.configuration = {
      system.nixos.tags = [ "cachyos-latest" ];
      boot.kernelPackages = lib.mkForce pkgs.cachyosKernels.linuxPackages-cachyos-latest-x86_64-v4;
    };
  };

```

### ⚠️ Important Cache Warning

Ensure `https://attic.xuyh0120.win/lantian` is explicitly defined in your `nix.settings.substituters`.

NixOS evaluates caches *before* downloading the kernel. If this is your first time enabling these kernels, it is highly recommended to run the rebuild command **twice**:

1. Run it once on your standard setup so NixOS registers the new Lantian binary cache keys.
2. Run it again to pull the compiled CachyOS kernels.

*(If you try to build immediately and see it start compiling `gcc` or `linux` from scratch, cancel the build (`Ctrl+C`), verify your substituters are active, and try again!)*
