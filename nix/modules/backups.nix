{ config, lib, options, secrets, ... }: let
  cfg = config.roos.backups;
  host = config.networking.hostName;
  mkUsername = client:
    truncate 32 "backup-from-${lib.toLower client}";  # See useradd(8).

  truncate = n: s: with lib; concatStrings (take n (stringToCharacters s));

  clientOpts = { name, ... }: with lib; {
    options.publicKey = mkOption {
      description = "SSH public key used by this client to push backups.";
      default = (secrets.forHost name).pubkeys.sshFor "backups";
      type = types.unspecified;
    };
  };

  targetOpts = { name, ... }: with lib; {
    options.basedir = mkOption {
      description = "Base directory where to store backups in this host.";
      default = let
        tRoot = cfg.registry."${name}".backupsRoot;
        msg =  "backupsRoot MUST be defined to use this host as a target.";
      in assert assertMsg (tRoot != null) msg; "${tRoot}/${host}";
      readOnly = true;
    };
  };

  regEntryOpts = with lib; {
    options.clients = mkOption {
      description = "Hosts allowed to send backups to this machine.";
      default = {};
      type = with types; let
        clientsAttrs = attrsOf (submodule clientOpts);
        asAttrset = members: genAttrs members (_: {});
        allInRegistry =
          # BUG: Check is not evaluated...
          assert false; v: all(host: hasAttr host cfg.registry) (attrNames v);
      in coercedTo (listOf str) asAttrset (addCheck clientsAttrs allInRegistry);
    };
    options.backupsRoot = mkOption {
      description = ''
        Where to store backups received by other machines.

        A directory will be created for every client, they will only be allowed
        to access that directory.
      '';
      type = let
        userOpts = options.users.users.type.nestedTypes.elemType.getSubOptions {};
      in types.nullOr userOpts.home.type;
      default = null;
    };
  };

in let  # Scope isolation of data
  registry = {
    Minerva.clients = [ "Mimir" ];
    Minerva.backupsRoot = "/mnt/cabinet/backups";
    Mimir = {};
  };
in {
  options.roos.backups = with lib; {
    registry = mkOption {
      description = ''
        Backup configuration is derived from a central registry.

        Compliance with the registry is not optional; if the machine's hostname
        (''${config.networking.hostName}) is in the registry; the configuration
        will be applied to the system configuration.

        A machine MUST be registered in order to interact with this module.
      '';
      default = registry;
      type = with types; (attrsOf (submodule regEntryOpts));
      readOnly = true;
    };

    registration = mkOption {
      description = "This machine's record in the backup registry.";
      readOnly = true;
      default = cfg.registry."${host}" or {};
      type = types.submodule regEntryOpts;
    };

    targets = mkOption {
      description = ''
        Where this machine should send its backups.

        Must be a subset of the machines that accept backups from this client
        in the registry.
      '';
      type = with types; let
        hostIsClientInTarget = target:
          elem host (attrNames (cfg.registry."${target}".clients or {}));
        hostIsClientInAllTargets = targets:
          all hostIsClientInTarget (attrNames targets);
        asAttrset = members: genAttrs members (_: {});
        coercedType =
          coercedTo (listOf str) asAttrset (attrsOf (submodule targetOpts));
      in addCheck coercedType hostIsClientInAllTargets;
      default = let
        rWhereHostIsTarget =
          attrNames (filterAttrs (_: r: hasAttr host r.clients) cfg.registry);
      in genAttrs rWhereHostIsTarget (name: {});
    };

    remoteUser = mkOption {
      description = "Username used to transfer backups out of this host.";
      default = mkUsername host;
    };

    btrbkTargets = mkOption {
      description = "List of btrbk target strings for this host, for convenience.";
      default = mapAttrsToList (h: t: "ssh://${h}/${t.basedir}") cfg.targets;
      readOnly = true;
    };
  };

  config = with lib; mkIf (cfg.registration != {}) {
    # Create users for clients
    users.users = mkMerge (mapAttrsToList (client: clientCfg: {
      "${mkUsername client}" = {
        home = "${cfg.registration.backupsRoot}/${client}";
        group = "backup-receivers";
        createHome = true;
        isSystemUser = true;
        openssh.authorizedKeys.keys = toList clientCfg.publicKey;
      };
    }) cfg.registration.clients);
  };
}
