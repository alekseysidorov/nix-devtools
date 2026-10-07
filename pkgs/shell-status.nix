{ writeShellApplication }:

writeShellApplication {
  name = "shell-status";
  text = ''
    style=$1
    action=$2
    description=$3

    case $style in
      info) color='1;36' ;;
      success) color='1;32' ;;
      warning) color='1;33' ;;
      field) color='90' ;;
      *)
        echo "Unknown status style: $style" >&2
        exit 2
        ;;
    esac

    printf '\033[%sm%12s\033[0m  %s\n' "$color" "$action" "$description" >&2
  '';
}
