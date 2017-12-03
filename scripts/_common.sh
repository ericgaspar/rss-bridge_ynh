#
# Common variables
#

# Package version
VERSION="2017-08-19"

# Full sources tarball URL
SOURCE_URL="https://github.com/RSS-Bridge/rss-bridge/archive/${VERSION}.tar.gz"

# Full  sources tarball checksum
SOURCE_SHA256="176385ef1e0cc1ac929498515c446778027ae292635bf6addfec61eab3833b67"

# App package root directory should be the parent folder
PKGDIR=$(cd ../; pwd)

#
# Common helpers
#

# Source app helpers
. /usr/share/yunohost/helpers

# Execute a command as another user
# usage: exec_as USER COMMAND [ARG ...]
exec_as() {
  local USER=$1
  shift 1

  if [[ $USER = $(whoami) ]]; then
    eval $@
  else
    # use sudo twice to be root and be allowed to use another user
    sudo sudo -u "$USER" "$@"
  fi
}

# Execute a command through the wallabag console
# usage: exec_console AS_USER WORKDIR COMMAND [ARG ...]
exec_console() {
  local AS_USER=$1
  local WORKDIR=$2
  shift 2
  exec_as "$AS_USER" php "$WORKDIR/bin/console" --no-interaction --env=prod "$@"
}

# Download and extract sources to the given directory
# usage: extract_sources DESTDIR [AS_USER]
extract_sources() {
  local DESTDIR=$1
  local AS_USER=${2:-$USER}

  # retrieve and extract Roundcube tarball
  wb_tarball="/tmp/sources.tar.gz"
  rm -f "$wb_tarball"
  wget -q -O "$wb_tarball" "$SOURCE_URL" \
    || ynh_die "Unable to download sources tarball"
  echo "$SOURCE_SHA256 $wb_tarball" | sha256sum -c >/dev/null \
    || ynh_die "Invalid checksum of downloaded tarball"
  exec_as "$AS_USER" tar xf "$wb_tarball" -C "$DESTDIR" --strip-components 1 \
    || ynh_die "Unable to extract sources tarball"
  rm -f "$wb_tarball"

}


HUMAN_SIZE () {	# Transforms a Kb-based size to a human-readable size
	human=$(numfmt --to=iec --from-unit=1K $1)
	echo $human
}

WARNING () {	# Print on error output
	$@ >&2
}

QUIET () {	# redirect standard output to /dev/null
	$@ > /dev/null
}

CHECK_SIZE () {	# Check if enough disk space available on backup storage
	file_to_analyse=$1
	backup_size=$(sudo du --summarize "$file_to_analyse" | cut -f1)
	free_space=$(sudo df --output=avail "/home/yunohost.backup" | sed 1d)

	if [ $free_space -le $backup_size ]
	then
		WARNING echo "Not enough backup disk space for: $file_to_analyse."
		WARNING echo "Space available: $(HUMAN_SIZE $free_space)"
		ynh_die "Space needed: $(HUMAN_SIZE $backup_size)"
	fi
}

CHECK_USER () {	# Check user validity
# $1 = User
	ynh_user_exists "$1" || ynh_die "Wrong user"
}

CHECK_DOMAINPATH () {	# Check domain/path availability
	sudo yunohost app checkurl $domain$path_url -a $app
}

CHECK_FINALPATH () {	# Check if destination directory already exists
	final_path="/var/www/$app"
	test ! -e "$final_path" || ynh_die "This path already contains a folder"
}

#=================================================
# FUTURE YUNOHOST HELPERS - TO BE REMOVED LATER
#=================================================
 
# Normalize the url path syntax
# Delete a file checksum from the app settings
#
# $app should be defined when calling this helper
#
# usage: ynh_remove_file_checksum file
# | arg: file - The file for which the checksum will be deleted
ynh_delete_file_checksum () {
	local checksum_setting_name=checksum_${1//[\/ ]/_}	# Replace all '/' and ' ' by '_'
	ynh_app_setting_delete $app $checksum_setting_name
}
