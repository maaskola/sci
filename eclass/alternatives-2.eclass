# Copyright 2010-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
#  $

# Based in part upon 'alternatives.exlib' from Exherbo, which is:
# Copyright 2008, 2009 Bo Ørsted Andresen
# Copyright 2008, 2009 Mike Kelly
# Copyright 2009 David Leverton

# If your package provides pkg_postinst or pkg_prerm phases, you need to be
# sure you explicitly run alternatives_pkg_{postinst,prerm} where appropriate.

ALTERNATIVES_DIR="/etc/env.d/alternatives"

DEPEND=">=app-admin/eselect-1.3.4-r100"
RDEPEND="${DEPEND}
	!app-admin/eselect-blas
	!app-admin/eselect-cblas
	!app-admin/eselect-lapack"

# alternatives_for alternative provider importance source target [ source target [...]]
alternatives_for() {
	#echo alternatives_for "${@}"

	(( $# >= 5 )) && (( ($#-3)%2 == 0)) || \
		die "${FUNCNAME} requires exactly 3+N*2 arguments where N>=1"
	local x dupl alternative=${1} provider=${2} importance=${3}
	local index unique src target ret=0
	shift 3

	# make sure importance is a signed integer
	if [[ -n ${importance} ]] && ! [[ ${importance} =~ ^[0-9]+(\.[0-9]+)*$ ]]
	then
		eerror "Invalid importance (${importance}) detected"
		((ret++))
	fi

	[[ -d "${ED}${ALTERNATIVES_DIR}/${alternative}/${provider}" ]] || \
		dodir "${ALTERNATIVES_DIR}/${alternative}/${provider}"

	# keep track of provided alternatives for use in pkg_{postinst,prerm}.
	# keep a mapping between importance and provided alternatives
	# and make sure the former is set to only one value
	if ! has "${alternative}:${provider}" "${ALTERNATIVES_PROVIDED[@]}"; then
		index=${#ALTERNATIVES_PROVIDED[@]}
		ALTERNATIVES_PROVIDED+=( "${alternative}:${provider}" )
		ALTERNATIVES_IMPORTANCE[index]=${importance}
		[[ -n ${importance} ]] && echo "${importance}" > \
			"${ED}${ALTERNATIVES_DIR}/${alternative}/${provider}/_importance"
	else
		for ((index=0; index<${#ALTERNATIVES_PROVIDED[@]}; index++)); do
			if [[ ${alternative}:${provider} == ${ALTERNATIVES_PROVIDED[index]} ]]; then
				if [[ -n ${ALTERNATIVES_IMPORTANCE[index]} ]]; then
					if [[ -n ${importance} && ${ALTERNATIVES_IMPORTANCE[index]} != ${importance} ]]; then
						eerror "Differing importance (${ALTERNATIVES_IMPORTANCE[index]} != ${importance}) detected"
						((ret++))
					fi
				else
					ALTERNATIVES_IMPORTANCE[index]=${importance}
					[[ -n ${importance} ]] && echo "${importance}" \
						> "${ED}${ALTERNATIVES_DIR}/${alternative}/${provider}/_importance"
				fi
			fi
		done
	fi

	while (( $# >= 2 )); do
		src=${1//+(\/)/\/}; target=${2//+(\/)/\/}
		if [[ ${src} != /* ]]; then
			eerror "Source path must be absolute, but got ${src}"
			((ret++))

		else
			local reltarget= dir=${ALTERNATIVES_DIR}/${alternative}/${provider}${src%/*}
			while [[ -n ${dir} ]]; do
				reltarget+=../
				dir=${dir%/*}
			done

			reltarget=${reltarget%/}
			[[ ${target} == /* ]] || reltarget+=${src%/*}/
			reltarget+=${target}
			dodir "${ALTERNATIVES_DIR}/${alternative}/${provider}${src%/*}"
			dosym "${reltarget}" "${ALTERNATIVES_DIR}/${alternative}/${provider}${src}"

			# say ${ED}/sbin/init exists and links to /bin/systemd
			# (which doesn't exist yet)
			# the -e test will fail, so check for -L also
			if [[ -e ${ED}${src} || -L ${ED}${src} ]]; then
				local fulltarget=${target}
				[[ ${fulltarget} != /* ]] && fulltarget=${src%/*}/${fulltarget}
				if [[ -e ${ED}${fulltarget} || -L ${ED}${fulltarget} ]]; then
					die "${src} defined as provider for ${fulltarget}, but both already exist in \${ED}"
				else
					mv "${ED}${src}" "${ED}${fulltarget}" || die
				fi
			fi
		fi
		shift 2
	done

	[[ ${ret} -eq 0 ]] || \
		die "Errors detected for ${provider}, provided for ${alternative}"
}

alternatives-2_pkg_postinst() {
	local a alt provider alt_dir module_version="20130222" oldp newp
	for a in "${ALTERNATIVES_PROVIDED[@]}"; do
		alt="${a%:*}"
		provider="${a#*:}"
		alt_dir="${EROOT%/}/usr/share/eselect/modules/auto"
		if [[ ! -f "${alt_dir}/${alt}.eselect" \
			|| "$(sed -n 's:VERSION=[\|\"]\(.*\)[\|\"]:\1:p' "${alt_dir}/${alt}.eselect")" \
			-ne "${module_version}" ]]; then
			einfo "Creating ${alt} eselect module"
			if [[ ! -d ${alt_dir} ]]; then
				install -d "${alt_dir}" || eerror "Could not create eselect modules directory"
			fi
			cat > "${alt_dir}/${alt}.eselect" <<-EOF
				# This module was automatically generated by alternatives-2.eclass
				DESCRIPTION="Alternatives for ${alt}"
				VERSION="${module_version}"
				MAINTAINER="eselect@gentoo.org"
				ESELECT_MODULE_GROUP="Alternatives"

				ALTERNATIVE="${alt}"

				inherit alternatives
			EOF
			fi
		oldp="$(eselect ${alt} show)"
		eselect "${alt}" update "${provider}" || die "failed to update ${alt}"
		newp="$(eselect ${alt} show)"
		[[ ${oldp} != ${newp} ]] && einfo "Module ${alt} is now set to ${newp}"
	done
}

alternatives-2_pkg_postrm() {
	local a alt provider ignore oldp newp
	local autodir="${EROOT%/}/usr/share/eselect/modules/auto"
	for a in "${ALTERNATIVES_PROVIDED[@]}"; do
		alt="${a%:*}"
		provider="${a#*:}"
		oldp="$(eselect ${alt} show)"
		eselect "${alt}" update "${provider}"
		case $? in
			0)
				newp="$(eselect ${alt} show)"
				[[ ${oldp} != ${newp} ]] && einfo "Module ${alt} is now set to ${newp}"
				;;
			2)
				einfo "Removing unused eselect ${alt} module"
				rm "${autodir}/${alt}.eselect" || \
					eerror rm "${autodir}/${alt}.eselect" failed
				;;
			*)
				eerror eselect "${alt}" update "${provider}" returned $?
				die "failed to remove ${alt} module"
				;;
		esac
	done
	# remove possibly empty directory
	find "${autodir}" -maxdepth 0 -empty | read && rmdir "${autodir}"
}

EXPORT_FUNCTIONS pkg_postinst pkg_postrm
