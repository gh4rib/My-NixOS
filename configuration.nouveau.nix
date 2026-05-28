# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # --- Bootloader Configuration (Limine) ---
  boot.loader.systemd-boot.enable = false;

#  boot.loader.grub.enable = true;
#  boot.loader.grub.efiSupport = true;
#  boot.loader.grub.device = "nodev";
#  boot.loader.grub.useOSProber = false;

  boot.loader.limine.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.initrd.systemd.enable = true;

  # --- Official Latest Kernel ---
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # --- Global Host Hardening (Virt-Safe) ---
  # These parameters harden the host kernel while maintaining full compatibility
  # with KVM, VMware, VirtualBox, and container runtimes.
  boot.kernelParams = [
    "i915.enable_guc=3"        # Intel GPU Acceleration boot param
    "init_on_alloc=1"          # Sanitizes memory pages on allocation to prevent data leaks
    "init_on_free=1"           # Sanitizes memory pages on free to eliminate use-after-free remnants
    "page_alloc.shuffle=1"     # Randomizes page allocator freelists to disrupt exploitation targeting
    "slab_nomerge"             # Disables slab merging to prevent heap exploitation side-channels
    "randomize_kstack_offset=on" # Randomizes kernel stack offset on every system call
    "vsyscall=none"            # Disables legacy vsyscalls completely (obsolete exploit vector)
    "pti=on"                   # Forces Page Table Isolation to mitigate Meltdown-style side channels
  ];

  boot.kernel.sysctl = {
    # Information Leak Mitigations
    "kernel.kptr_restrict" = 2;          # Completely hides kernel pointers from unprivileged users
    "kernel.dmesg_restrict" = 1;         # Restricts dmesg access to root/wheel users
    "kernel.unprivileged_bpf_disabled" = 1; # Prevents unprivileged users from executing eBPF (spectre mitigation)
    "net.core.bpf_jit_harden" = 2;       # Enforces strict JIT hardening for all users

    # Network Stack Hardening
    "net.ipv4.conf.all.rp_filter" = 1;   # Enables strict reverse path filtering to prevent IP spoofing
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0; # Ignores ICMP redirect route alterations
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;   # Host will not act as a rogue router
  };

  # Host-level Security Knobs
  security.sudo.execWheelOnly = true;    # Prevents non-wheel users from even attempting sudo execution
  security.protectKernelImage = true;    # Protects the kernel image in memory from being modified post-boot

  # --- Nix Package Manager Settings ---
  nix.settings.substituters = lib.mkForce [ 
    "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store" 
    "https://attic.xuyh0120.win/lantian" 
  ];
  nix.settings.trusted-public-keys = [ 
    "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" 
  ];
  nix.settings.substitute = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # --- Networking & System Environment ---
  networking.hostName = "whalers0"; 
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;
  time.timeZone = "Asia/Tehran";
  i18n.defaultLocale = "en_US.UTF-8";

  # --- Hardware Security & Mandatory Access Control ---
  security.tpm2.enable = true;
  security.tpm2.pkcs11.enable = true;
  security.tpm2.tctiEnvironment.enable = true;
  security.apparmor.enable = true;
  security.apparmor.packages = [ pkgs.apparmor-utils pkgs.apparmor-profiles ];

  # --- Hardware Acceleration (Ice Lake 10th Gen Specific) ---
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver 
      intel-vaapi-driver 
#      intel-media-sdk
      vpl-gpu-rt
      intel-compute-runtime
      libvdpau-va-gl
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [
      intel-media-driver
      intel-vaapi-driver
      libvdpau-va-gl
    ];
  };

  # --- Environment Variables (Wayland & Hardware Routing) ---
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
    VDPAU_DRIVER = "va_gl";
#    NIXOS_OZONE_WL = "1"; # Forces native Wayland on Chromium/Electron
  };
  

  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "modesetting" "nouveau" ];

  hardware.enableRedistributableFirmware = true;  

  # --- Desktop Environment & Audio ---
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.xserver.xkb.layout = "us";
  
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  services.libinput.enable = true;

  # --- Flatpak & Desktop Portals ---
  services.flatpak.enable = true;
  xdg.portal.enable = true;

  # --- Virtualization Stack ---
  
  # KVM / QEMU
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_full;
      runAsRoot = false;
      swtpm.enable = true;
    };
  };
  programs.virt-manager.enable = true;

  # LXC
  virtualisation.lxc.enable = true;
  virtualisation.lxc.lxcfs.enable = true;

  # Docker & Podman
  virtualisation.docker.enable = true;
  virtualisation.podman = {
    enable = true;
    dockerCompat = false;
    defaultNetwork.settings.dns_enabled = true;
  };

  # Incus (Configured with directory preseed)
  virtualisation.incus = {
    enable = true;
    ui.enable = true;
    preseed = {
      networks = [
        {
          name = "incusbr0";
          type = "bridge";
          config = {
            "ipv4.address" = "10.0.100.1/24";
            "ipv4.nat" = "true";
          };
        }
      ];
      storage_pools = [
        {
          name = "default";
          driver = "dir";
          config = {
            source = "/var/lib/incus/storage-pools/default";
          };
        }
      ];
      profiles = [
        {
          name = "default";
          devices = {
            eth0 = {
              name = "eth0";
              network = "incusbr0";
              type = "nic";
            };
            root = {
              path = "/";
              pool = "default";
              size = "100GiB";
              type = "disk";
            };
          };
        }
      ];
    };
  };

  # VirtualBox
  virtualisation.virtualbox.host.enable = true;

  # VMware Workstation
  virtualisation.vmware.host.enable = true;

  # Waydroid
  virtualisation.waydroid.enable = true;

  # --- User Configuration ---
  users.users.daud = {
    isNormalUser = true;
    description = "Alireza Gharib";
    extraGroups = [ 
      "wheel" "networkmanager" "libvirtd" "kvm" "docker" 
      "incus-admin" "vboxusers" "vmware"
    ]; 
  };

  # --- System Services ---
  programs.dconf.enable = true;
  programs.firefox.enable = true;
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  services.openssh.enable = true;

  # Disable GNOME localsearch indexing
  systemd.user.services."localsearch-3".enable = lib.mkForce false;
  systemd.user.services."localsearch-control-3".enable = lib.mkForce false;
  systemd.user.services."localsearch-writeback-3".enable = lib.mkForce false;

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
    priority = 100;
  };

  # --- System Packages ---
  environment.systemPackages = with pkgs; [
    vim wget htop dnsutils btop
    qemu_full qemu-utils OVMFFull
    spice-vdagent virglrenderer seabios-qemu
    podman-compose podman-desktop bridge-utils lxc
    vulkan-tools
    gcc llvm clang papers
    ffmpeg-full shotwell openh264 vlc rhythmbox obs-studio
    curl git alacritty gnome-boxes ghostty python3
    cifs-utils
    virtiofsd virtio-win virt-manager virt-viewer
    spice spice-gtk spice-protocol neovim gedit keepassxc
  ];

  # --- Boot Specialisations ---
  specialisation = {
    
    # 1. The Compartmentalized Hypervisor Mode (Type-1)
    xen.configuration = {
      system.nixos.tags = [ "xen" ];
      virtualisation.xen.enable = true;
      virtualisation.xen.boot.params = [ "dom0=pvh nestedhvm=1" ];
      
      # Explicitly strip Type-2 out-of-tree hypervisors and Waydroid to preserve Dom0 integrity
      virtualisation.virtualbox.host.enable = lib.mkForce false;
      virtualisation.vmware.host.enable = lib.mkForce false;
      virtualisation.waydroid.enable = lib.mkForce false;
      
      hardware.enableRedistributableFirmware = true;
    };

    # 2. Maximum Hardened Station (Native Virt Only)
    # Reboots system into upstream linux-hardened. VMware/VirtualBox are dropped, 
    # but KVM, Incus, Docker, and Podman operate natively under high-defense patches.
    hardened-workstation.configuration = {
      system.nixos.tags = [ "hardened-workstation" ];
      boot.kernelPackages = lib.mkForce pkgs.linuxPackages_hardened;

      # Out-of-tree closed source hypervisors fail compilation against hardened structures.
      virtualisation.virtualbox.host.enable = lib.mkForce false;
      virtualisation.vmware.host.enable = lib.mkForce false;
    };

    # 3. CachyOS BORE Scheduler + AVX512 (v4)
    cachyos-bore.configuration = {
      system.nixos.tags = [ "cachyos-bore" ];
      boot.kernelPackages = lib.mkForce pkgs.cachyosKernels.linuxPackages-cachyos-bore-x86_64-v4;
    };

    # 4. CachyOS EEVDF (Latest) + AVX512 (v4)
    cachyos-latest-lto.configuration = {
      system.nixos.tags = [ "cachyos-latest" ];
      boot.kernelPackages = lib.mkForce pkgs.cachyosKernels.linuxPackages-cachyos-latest-x86_64-v4;
    };
  };

  system.stateVersion = "25.11"; 
}
