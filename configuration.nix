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
  boot.loader.grub.enable = false;
  boot.loader.limine.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.initrd.systemd.enable = true;

  security.sudo.execWheelOnly = true;

  # --- Official Latest Kernel ---
  boot.kernelPackages = pkgs.linuxPackages_latest;

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

  # --- Hardware Security ---
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
      # Video Decoding
      intel-media-driver 
      intel-vaapi-driver 
      
      # Quick Sync Video (QSV) explicitly for 10th Gen & Older
      intel-media-sdk 
      
      # OpenCL Compute explicitly for Gen8 - Gen11 architectures
      intel-compute-runtime-legacy1
      nvidia-vaapi-driver
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [
      intel-vaapi-driver
    ];
  };

  # --- Environment Variables (Wayland & Hardware Routing) ---
  environment.sessionVariables = {
    # Force video playback to use the Intel iGPU, bypassing NVIDIA for efficiency
    LIBVA_DRIVER_NAME = "iHD";
  };

  # --- Graphics: NVIDIA MX110 Proprietary Hybrid ---
  services.xserver.enable = true;
  
  # "modesetting" MUST be explicitly listed before "nvidia" for Offload mode
  services.xserver.videoDrivers = [ "modesetting" "nvidia" ];
  
  hardware.nvidia = {
    # Modesetting is strictly required for Wayland support on NVIDIA
    modesetting.enable = true;
    open = false; 
    nvidiaSettings = true;
    
    # Power management allowed, but finegrained MUST be false for Maxwell (MX110)
    powerManagement.enable = false;
    powerManagement.finegrained = false; 
    
    # Explicitly pin to the 580 branch to prevent 590+ breakage
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580; 

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true; 
      };
      # RUN `lspci` to verify these numbers. Example: 00:02.0 becomes 0@0:2:0
      intelBusId = "PCI:0@0:2:0";
      nvidiaBusId = "PCI:1@0:0:0";
    };
  };

  # --- Desktop Environment & Audio ---
  # GDM natively uses Wayland by default. 
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

  # Incus (Configured exactly to your preseed specifications)
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

  # Waydroid (Android Emulation natively on Wayland)
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
  services.openssh.enable = false;

  # Disable GNOME localsearch memory hogs
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
    qemu-user qemu qemu_kvm
    podman-compose podman-desktop bridge-utils lxc
    mesa mesa-demos 
    
    # Vulkan Support explicitly exposed
    vulkan-tools vulkan-loader vulkan-headers vulkan-validation-layers
    
    gimp pinta gcc llvm clang papers
    ffmpeg-full shotwell openh264 vlc rhythmbox obs-studio
    curl git alacritty gnome-boxes calibre thunderbird filezilla
    flameshot shutter hexchat pidgin persepolis qbittorrent qtox
    claws-mail ghostty go rustc rustfmt ruby lua python3
    jdk11 jdk25 openvpn3 sstp nodejs cargo cifs-utils
    virtiofsd virtio-win virt-manager virt-viewer
    spice spice-gtk spice-protocol chromium neovim gedit keepassxc
  ];

  # --- Specialisation: Xen Hypervisor + Nouveau ---
  specialisation = {
    xen-nouveau.configuration = {
      system.nixos.tags = [ "xen-nouveau" ];
      
      virtualisation.xen.enable = true;
      virtualisation.xen.boot.params = [ "nestedhvm=1" ];

      # Explicitly disable Type-2 hypervisors & Waydroid in Dom0
      virtualisation.virtualbox.host.enable = lib.mkForce false;
      virtualisation.vmware.host.enable = lib.mkForce false;
      virtualisation.waydroid.enable = lib.mkForce false;

      # Force X11/Wayland to use Nouveau, bypassing the proprietary module
      services.xserver.videoDrivers = lib.mkForce [ "modesetting" "nouveau" ];
      hardware.enableRedistributableFirmware = true;
    };
  };

  system.stateVersion = "25.11"; 
}
