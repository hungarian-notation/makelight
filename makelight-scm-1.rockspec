package = "makelight"
version = "scm-1"
source = {
   url = "git://github.com/hungarian-notation/makelight.git"
}
description = {
   homepage = "http://eonz.net/p/makelight",
   license = "GNU GPL v3"
}
dependencies = { "penlight >= 1.5.4" }
build = {
   type = "builtin",
   modules = {
	   ["ml"] 			= "src/lua/ml/init.lua";
	   ["ml.util"]		= "src/lua/ml/util.lua";
	   ["ml.color"] 	= "src/lua/ml/color.lua";
	   ["ml.sequence"]	= "src/lua/ml/sequence.lua";
	   ["ml.channels"]	= "src/lua/ml/channels.lua";
	   ["ml.common"]	= "src/lua/ml/common.lua";
	   ["ml.timing"]	= "src/lua/ml/timing.lua";
	   ["ml.cursor"]	= "src/lua/ml/cursor.lua";

	   ["ml.formats.lightshow"]	= "src/lua/ml/formats/lightshow.lua";

   }
}
