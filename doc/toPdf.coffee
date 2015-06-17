spawn = require("child_process").spawn
path = require('path')
fs = require "fs"
ect = require("ect")()
argv = require('minimist')(process.argv.slice(2))

inputFiles = argv.i
if typeof inputFiles is "string"
	inputFiles = [inputFiles]

output = argv.o


defaultArgs = "
-o #{output}
-V documentclass=article 
-H zhawsettings.tex 
-s 

--listing 
--filter pandoc-citeproc 
--number-sections 
--template=template.latex
"
# --table-of-contents 

precompileAndRead = (file) ->
	extension = path.extname file
	switch extension
		when ".ect" then ect.render file
		else fs.readFileSync file

pandoc = spawn "pandoc", defaultArgs.split(" ")

pandoc.stderr.on "data", (data) ->
	console.error data.toString "utf-8"

for file in inputFiles
	pandoc.stdin.write precompileAndRead file

pandoc.stdin.end()
