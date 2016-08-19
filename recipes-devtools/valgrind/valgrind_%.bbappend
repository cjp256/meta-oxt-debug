PR .= "0.3"

#If we're /not/ in the stubdomain, depend on libx11.
#DEPENDS := "${@base_conditional("MACHINE", "xenclient-stubdomain", "", "libx11", d)}"
DEPENDS = ""
RDEPENDS_${PN} += "libc6-dbg"

#Yes, Valrgind really does depend on there being some debug metadata at runtime.
#This tells bitbake not to panic about it.
INSANE_SKIP_${PN} += "debug-deps"

