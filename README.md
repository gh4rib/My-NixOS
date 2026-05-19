# ❄️ NixOS Configuration: CachyOS v4 & LTO

Welcome to my personal NixOS configuration! This repository utilizes **Nix Flakes** to build a highly optimized, reproducible Linux environment tailored for modern processors.

The core feature of this setup is the integration of the [CachyOS Kernel](https://github.com/xddxdd/nix-cachyos-kernel), heavily optimized with **Clang + ThinLTO** and compiled specifically for **x86_64-v4** CPU architectures (leveraging AVX-512 instructions).

## ✨ Features
* **Flake-Based:** Fully reproducible system state locked down by `flake.lock`.
* **CachyOS Kernels:** Utilizing the `xddxdd/nix-cachyos-kernel` repository.
* **LTO & v4 Optimizations:** Aggressive compiler-level and hardware-level optimizations for maximum responsiveness and throughput.
* **Boot Menu Specialisations:** Employs NixOS `specialisation` to generate multiple boot entries. If an experimental kernel fails, stable fallback kernels are just a reboot away.
* **Pre-Compiled Binaries:** Configured to pull from official binary caches (`lantian` and `garnix`) to avoid hours of local compilation.

## ⚠️ Hardware Warning
The default kernel in this configuration targets the **`x86_64-v4`** microarchitecture tier. 
**Do not use the v4 specialisations unless you have a compatible CPU** (e.g., AMD Zen 4+, Intel Skylake-X/Ice Lake+). Booting a v4 kernel on unsupported hardware will result in an "Illegal Instruction" kernel panic.

## 🚀 Usage

If you are adapting this for your own machine, **ensure you add the binary caches first** before applying the kernel, or your machine will attempt to compile the LTO kernel from source.

1. Clone the repository to `/etc/nixos`:
```bash
sudo git clone [https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git](https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git) /etc/nixos
```

2. Update the `flake.lock` file to fetch the latest inputs:
```bash
sudo nix flake update --flake /etc/nixos
```

3. Rebuild the system:
```bash
sudo nixos-rebuild switch --flake /etc/nixos#yourhostname
```

## 🥾 Boot Menu Structure
Upon rebuilding, NixOS will automatically generate the following entries in your bootloader via the `specialisation` module:

* `NixOS - Default` *(CachyOS LTS LTO v4)*
* `NixOS - cachyos-lto-v4` *(Latest CachyOS release)*
* `NixOS - standard-nixos` *(Standard NixOS mainline kernel fallback)*

---
*Built with ❤️ on NixOS 25.11*
