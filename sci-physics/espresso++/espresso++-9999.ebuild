# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5

PYTHON_COMPAT=( python2_7 )
CMAKE_MAKEFILE_GENERATOR="ninja"

inherit cmake-utils python-single-r1

DESCRIPTION="extensible, flexible, fast and parallel simulation software for soft matter research"
HOMEPAGE="https://www.espresso-pp.de"

MY_PN="${PN//+/p}"
if [[ ${PV} = 9999 ]]; then
	EGIT_REPO_URI="git://github.com/${MY_PN}/${MY_PN}.git http://github.com/${MY_PN}/${MY_PN}.git"
	inherit git-r3
	KEYWORDS=
else
	#SRC_URI="https://espressopp.mpip-mainz.mpg.de/Download/${PN//+/p}-${PV}.tgz"
	SRC_URI="https://github.com/${MY_PN}/${MY_PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~x86 ~amd64-linux ~x86-macos"
fi

LICENSE="GPL-3"
SLOT="0"
IUSE=""

REQUIRED_USE="${PYTHON_REQUIRED_USE}"

RDEPEND="${PYTHON_DEPS}
	virtual/mpi
	dev-libs/boost:=[python,mpi,${PYTHON_USEDEP}]
	sci-libs/fftw:3.0
	dev-python/mpi4py"
DEPEND="${RDEPEND}"

src_configure() {
	local mycmakeargs=(
		-DEXTERNAL_BOOST=ON
		-DEXTERNAL_MPI4PY=ON
		-DWITH_RC_FILES=OFF
	)
	cmake-utils_src_configure
}
