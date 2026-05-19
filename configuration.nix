# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.useOSProber = false;

#  boot.loader.limine.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.initrd.systemd.enable = true;
#  boot.protectKernelImage = true;
#  boot.kernelParams = [
#    "splash"
#    "quit"
#    "debugfs=off"
#    "init_on_alloc=1"
#    "init_on_free=1"
#    "page_alloc.shuffle=1"
#    "slab_nomerge"
#    "pti=on"
#    "kaslr"
#    "randomize_kstack_offset=on"
#    "vsyscall=none"
#  ];
#  boot.kernel.sysctl = {
#    "kernel.kptr_restrict" = 2;
#    "kernel.dmesg_restrict" = 1;
#    "kernel.unprivileged_bpf_disabled" = 1;
#  };
  security.sudo.execWheelOnly = true;
  # Use latest kernel.
#  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-x86_64-v4;

  specialisation = {
    cachyos-bore-lto-kernel.configuration = {
      system.nixos.tags = [ "cachyos-bore-lto-kernel" ];
      boot.kernelPackages = pkgs.lib.mkForce pkgs.cachyosKernels.linuxPackages-cachyos-bore-lto-x86_64-v4;
    };
    cachyos-bore-kernel.configuration = {
      system.nixos.tags = [ "cachyos-bore-kernel" ];
      boot.kernelPackages = pkgs.lib.mkForce pkgs.cachyosKernels.linuxPackages-cachyos-bore-x86_64-v4;
    };
#    cachyos-lts-kernel.configuration = {
#      system.nixos.tags = [ "cachyos-lts-kernel" ];
#      boot.kernelPackages = pkgs.lib.mkForce pkgs.cachyosKernels.linuxPackages-cachyos-lts-x86_64-v4;
#    };
#    cachyos-lts-lto-kernel.configuration = {
#      system.nixos.tags = [ "cachyos-lts-lto-kernel" ];
#      boot.kernelPackages = pkgs.lib.mkForce pkgs.cachyosKernels.linuxPackages-cachyos-lts-lto-x86_64-v4;
#    };
    cachyos-latest-lto-kernel.configuration = {
      system.nixos.tags = [ "cachyos-latest-lto-kernel" ];
      boot.kernelPackages = pkgs.lib.mkForce pkgs.cachyosKernels.linuxPackages-cachyos-latest-lto-x86_64-v4;
    };
    latest-kernel.configuration = {
      system.nixos.tags = [ "latest-kernel" ];
      boot.kernelPackages = pkgs.lib.mkForce pkgs.linuxPackages_latest;
    };
#    lts.configuration = {
#      system.nixos.tags = [ "lts-kernel" ];
#      boot.kernelPackages = pkgs.lib.mkForce pkgs.linuxPackages;
#    };
  };

  nix.settings.substituters = lib.mkForce [ "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store" "https://attic.xuyh0120.win/lantian" ];
  nix.settings.trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];
  nix.settings.substitute = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
#  nix.settings.auto-optimise-store = true;
  nixpkgs.config.allowUnfree = true;

  networking.hostName = "whalers0"; # Define your hostname.

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Tehran";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  security.tpm2.enable = true;
  security.tpm2.pkcs11.enable = true;
  security.tpm2.tctiEnvironment.enable = true;
  security.apparmor.enable = true;
  security.apparmor.packages = [ pkgs.apparmor-utils pkgs.apparmor-profiles ];

#  virtualisation.xen.enable = true;
#  virtualisation.xen.boot.params = [ "nestedhvm=1" ];
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_full;
      runAsRoot = false;
      swtpm.enable = true;
#      ovmf.enable = true;
#      ovmf.packages = [ pkgs.OVMFFull.fd ];
    };
  };
  programs.virt-manager.enable = true;
  programs.dconf.enable = true;

  virtualisation.lxc.enable = true;
  virtualisation.lxc.lxcfs.enable = true;
#  virtualisation.docker.enable = true;
  virtualisation.podman = {
    enable = true;
    dockerCompat = false;
    defaultNetwork.settings.dns_enabled = true;
  };
  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
#  console = {
#    font = "Lat2-Terminus16";
#    keyMap = "us";
#    useXkbConfig = true; # use xkb.options in tty.
#  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;


  # Configure keymap in X11
  services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  services.xserver.videoDrivers = [ "modesetting" "nouveau" ];
  # Enable sound.
  services.pulseaudio.enable = false;
  # OR
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.daud = {
    isNormalUser = true;
    description = "Alireza Gharib";
    extraGroups = [ "wheel" "networkmanager" "libvirtd" "kvm" "docker" ]; # Enable ‘sudo’ for the user.
  #   packages = with pkgs; [
  #     tree
  #   ];
  };

  programs.firefox.enable = true;

  systemd.user.services."localsearch-3".enable = lib.mkForce false;

  systemd.user.services."localsearch-control-3".enable = lib.mkForce false;

  systemd.user.services."localsearch-writeback-3".enable = lib.mkForce false;

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
    priority = 100;
  };

#  boot.initrd.luks.devices."cryptmystorage0" = {
#    device = "/dev/disk/by-uuid/ad29d152-2c75-4612-a6ae-0c6b78a2ac10";
#    allowDiscards = true;
#  };
#  fileSystems."/mnt/mystorage0" = {
#    device = "/dev/mapper/cryptmystorage0";
#    fsType = "btrfs";
#    options = [ "compress=zstd" "defaults" ];
#  };

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    htop
    dnsutils
    btop
    qemu_full
    qemu-utils
    OVMFFull
    spice-vdagent
    virglrenderer
    seabios-qemu
#    xen
    qemu-user
    qemu
#    qemu_xen
    qemu_kvm
#    ubootQemuX86
#    ubootQemuX86_64
#    ubootQemuArm
#    ubootQemuAarch64
#    docker-compose
    podman-compose
    podman-desktop
    bridge-utils
    lxc
    mesa
    mesa-demos
    vulkan-tools
    vulkan-loader
    vulkan-headers
    gimp
    pinta
    gcc
    llvm
    clang
    papers
    ffmpeg-full
    shotwell
#    ristretto
    openh264
    vlc
    rhythmbox
    obs-studio
    curl
    git
    alacritty
    gnome-boxes
    calibre
    thunderbird
    filezilla
    flameshot
    shutter
    hexchat
    pidgin
    persepolis
    qbittorrent
    qtox
    claws-mail
#    obsidian
    ghostty
    go
    rustc
    rustfmt
    ruby
    lua
    python3
#    python2
    jdk11
    jdk25
    openvpn3
    sstp
    nodejs
    cargo
    cifs-utils
    virtiofsd
    virtio-win
    virt-manager
    virt-viewer
    spice
    spice-gtk
    spice-protocol
    chromium
#    google-chrome
    neovim
    gedit
    keepassxc
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = true;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
#  system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}
