# 🛡️ NixSec-Virt: The Declarative Analyst Workstation

A production-ready, highly compartmentalized NixOS configuration engineered specifically for cybersecurity analysts, malware researchers, and security engineers.

This configuration transforms a standard laptop into a reproducible, full-stack virtualization lab. By combining the declarative power of NixOS with a massive array of hypervisors and container runtimes, it enables analysts to simulate complex network topologies, safely detonate malware, and reverse-engineer mobile applications—all from a single, immutable host system.

## 🎯 Why This Exists

Security analysis requires strict isolation. Traditional Linux distributions suffer from "dependency rot" when juggling multiple virtualization toolchains, proprietary drivers, and isolated environments.

**NixSec-Virt** solves this by treating the entire analyst operating system as code. It leverages an Intel/NVIDIA hybrid graphics stack (with explicitly pinned drivers) and deploys an entire lab environment natively, ensuring that your tools never conflict and your host OS remains mathematically reproducible.

## 🏗️ The Virtualization Arsenal

This system comes pre-configured with a multi-tiered virtualization stack, allowing you to choose the exact level of isolation required for your threat model:

### 1. Bare-Metal Isolation (Type-1)

* **Xen Hypervisor:** A dedicated boot menu specialisation turns the system into a Xen `Dom0`. By explicitly disabling Type-2 hypervisors and proprietary NVIDIA drivers in this mode, it creates a pristine, highly compartmentalized environment ideal for hypervisor vulnerability research and strict OS isolation.

### 2. High-Performance Hardware Virtualization (Type-2)

* **KVM / QEMU (Libvirt):** The default workhorse for malware detonation and deploying Intrusion Detection Systems (IDS). Pre-configured with TPM 2.0 (swtpm) for testing modern Windows 11 payloads or Secure Boot bypasses.
* **VMware Workstation & VirtualBox:** Natively supported and isolated for analyzing legacy enterprise OVA/OVF templates or running proprietary security appliances.

### 3. High-Density Network Simulation (System Containers)

* **Incus (LXD Fork):** Pre-seeded with a custom `incusbr0` NAT bridge and directory-backed storage. Perfect for spinning up dozens of lightweight Linux nodes to simulate complex topologies (like vehicular ad-hoc networks or enterprise Active Directory segments) with near-zero overhead.
* **LXC / LXCFS:** Core kernel-level isolation for system containers.

### 4. Microservices & Application Security

* **Podman & Docker:** Fully integrated for auditing vulnerable web applications, testing container breakouts, or running isolated forensic tools without root privileges.

### 5. Mobile Emulation

* **Waydroid:** A complete, hardware-accelerated Android environment running natively on Wayland. Designed for dynamic APK analysis, intercepting mobile TLS traffic, and reverse-engineering Android malware without needing a physical test device.

---

## 💻 Hardware Architecture & Optimization

* **Wayland First:** Fully configured with `xdg-desktop-portal` and Ozone environment variables to enforce native Wayland rendering for modern applications, minimizing the X11 attack surface.
* **NVIDIA PRIME Offload:** Runs the desktop securely on the Intel iGPU to preserve battery life, while exposing the NVIDIA GPU via an explicit offload wrapper. Perfect for executing localized, GPU-accelerated workloads (e.g., Hashcat cracking or training Deep Learning anomaly detection models) only when requested.
* **Legacy Hardware Support:** Explicitly pinned to the `legacy_580` NVIDIA branch and `intel-compute-runtime-legacy1` to ensure perfect OpenCL and CUDA functionality on Gen 10/11 Intel architectures and Maxwell-based GPUs.

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

## 🧠 Specialisation: The Xen "Red Pill" Mode

When booting your machine, the Limine bootloader will present a secondary NixOS entry. Selecting this will boot the system with the Xen specialisation.

In this mode:

1. The Type-1 Xen Hypervisor takes over the hardware.
2. The proprietary NVIDIA stack is stripped out.
3. The open-source `nouveau` driver is injected.
4. VMware, VirtualBox, and Waydroid are disabled to prevent kernel module conflicts.

This effectively gives you a dual-personality workstation: a hybrid-graphics Wayland desktop for daily analysis, and a strict Xen hypervisor for advanced compartmentalization research.


Since the popular Chaotic Nyx project was suddenly archived and killed in December 2025, the `xddxdd/nix-cachyos-kernel` repository has become the absolute gold standard for getting these highly tuned kernels on NixOS.

Because your 10th Gen Ice Lake CPU natively supports AVX-512 instructions, compiling the kernel with the `x86_64-v4` optimizations (like you specified in your original file) will yield fantastic performance improvements.

To safely inject these custom kernels into your setup without breaking the rest of your system, you have to split the configuration into two parts: adding the Flake input, and defining the boot menu specialisations.

### Step 1: Update `flake.nix` (The Input & Overlay)

You must first tell your Nix system where to fetch the CachyOS packages from and apply them as an "overlay" over your standard packages.

Add the `nix-cachyos-kernel` input to your `flake.nix`, and make sure to use the `release` branch so you actually hit the binary cache (saving you from compiling a kernel for hours!).

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

Now that `pkgs.cachyosKernels` exists in your system, you can add your custom boot entries back.

Scroll down to the very bottom of your `configuration.nix`. You already have one specialisation for `xen-nouveau`. You just need to merge your CachyOS entries into that exact same block.

Replace your existing `specialisation = { ... }` block with this combined one:

```nix
  # --- Boot Specialisations ---
  specialisation = {
    
    # 1. The Compartmentalized Hypervisor Mode
    xen-nouveau.configuration = {
      system.nixos.tags = [ "xen-nouveau" ];
      virtualisation.xen.enable = true;
      virtualisation.xen.boot.params = [ "nestedhvm=1" ];
      virtualisation.virtualbox.host.enable = lib.mkForce false;
      virtualisation.vmware.host.enable = lib.mkForce false;
      virtualisation.waydroid.enable = lib.mkForce false;
      services.xserver.videoDrivers = lib.mkForce [ "modesetting" "nouveau" ];
      hardware.enableRedistributableFirmware = true;
    };

    # 2. CachyOS BORE Scheduler + LTO + AVX512 (v4)
    cachyos-bore-lto.configuration = {
      system.nixos.tags = [ "cachyos-bore-lto" ];
      boot.kernelPackages = lib.mkForce pkgs.cachyosKernels.linuxPackages-cachyos-bore-lto-x86_64-v4;
    };

    # 3. CachyOS BORE Scheduler + AVX512 (v4)
    cachyos-bore.configuration = {
      system.nixos.tags = [ "cachyos-bore" ];
      boot.kernelPackages = lib.mkForce pkgs.cachyosKernels.linuxPackages-cachyos-bore-x86_64-v4;
    };

    # 4. CachyOS EEVDF (Latest) + LTO + AVX512 (v4)
    cachyos-latest-lto.configuration = {
      system.nixos.tags = [ "cachyos-latest-lto" ];
      boot.kernelPackages = lib.mkForce pkgs.cachyosKernels.linuxPackages-cachyos-latest-lto-x86_64-v4;
    };
  };

```

### Important Cache Warning

You already have `[https://attic.xuyh0120.win/lantian](https://attic.xuyh0120.win/lantian)` explicitly defined in your `nix.settings.substituters` (which is the correct binary cache for the xddxdd kernels).

However, NixOS evaluates caches *before* it tries to download the kernel. If this is your first time enabling these kernels, it is highly recommended to run the rebuild command **twice**:

1. Run it once on your standard setup so NixOS registers the new Lantian binary cache keys.
2. Run it again to actually pull the CachyOS kernels.

If you try to build it immediately and see it start compiling `gcc` or `linux`, cancel the build (`Ctrl+C`), verify your substituters are active, and try again!
