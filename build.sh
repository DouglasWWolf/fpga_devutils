#==============================================================================
# This looks up the Vivado version number that was used to create the project
# and ensures that the same version is used to process it here
#==============================================================================
get_vivado()
{
   version=
   grep 2024.2 $1 >/dev/null && version=2024.2
   grep 2021.1 $1 >/dev/null && version=2021.1
   if [ -z $version ]; then
       echo "Unable to determine Vivado version for $project"
       exit 1
   fi
   new=$(echo $VIVADO | sed "s/Vivado\/20[0-9][0-9]\.[0-9]/Vivado\/${version}/g")

   # Extract the first token of $VIVADO and display it
   read new _ <<<$new
   echo $new
}
#==========================================================================


#==================================================================
# This function will find "git_hash.vh" in the current directory
# tree, and silently update it to contain the git-hash of the
# most recent commit, formatted as a Verilog "localparam".
#
# This function will not affect the "last-modified" date of the
# "git_hash.vh" file, so the Vivado IPI won't erroneously complain
# that we have updated a module.
#
# Function options:
#  --dir <working_directory_name>
#  --hash <string_of_hex>
#
# Doug Wolf wrote this
#==================================================================
update_githash_file()
{
    # We don't know what our hash is yet
    local hash=
    
    # We don't have a fully qualified path to our updateable file yet
    local fqp=

    # This is the basename of the file we're going to update
    local ofile=git_hash

    # Sit in a loop and parse the command line options
    while [ ! -z $1 ]; do

        # Did the caller hand us a hash on the command line?
        if [ "$1" == "--hash" ]; then
            hash=$2
            shift
            shift
            continue
        fi

        # Did the caller hand us a directory name on the command line?
        if [ "$1" == "--dir" ]; then
            local dir=$2
            if [ -z $dir ] || [ ! -d $dir ]; then 
                echo "$dir not found!" 1>&2
                return 3
            fi
            cd $dir
            shift
            shift
            continue
        fi

        # If we get here, the caller screwed up
        echo "Unknown option $1" 1>&2
        return 4

    done


    # If the current directory isn't a git repo, complain and quit
    if [ ! -d .git ]; then
        echo "$PWD is not a git repo!" 1>&2
        return 1
    fi

    # If the hash-file doesn't exist in the current directory, find it
    if [ -f ${ofile}.vh ]; then
        fqp=${ofile}.vh
    else
        fqp=$(find . | grep "/${ofile}\.vh$")
    fi

    # If we couldn't find a hash-file, complain
    if [ -z $fqp ]; then
        echo "${ofile}.vh not found under $PWD !" 1>&2
        return 2
    fi

    # If the caller didn't hand us a hash, find the git-hash of
    # the most recent commit
    if [ -z $hash ]; then
        hash=$(git log -1 --pretty=format:"%H")
    fi

    # Create a verilog header file with the git-hash
    echo "//"                                                 >new_hash.vh
    echo "// -- DO NOT EDIT! -- this file is auto-generated" >>new_hash.vh
    echo "//"                                                >>new_hash.vh
    echo "localparam[159:0] GIT_HASH = 160'h${hash};"        >>new_hash.vh

    # Copy our new hashfile into the project source, but *without* updating
    # the "last modified time" or any other meta-data.   This will prevent
    # Vivado from erroneously thinking that we've updated a module.
    cp -p new_hash.vh $fqp

    # And we don't need our temporary output file anymore
    rm -rf new_hash.vh
}
#==================================================================


# Determine the name of the Vivado project file
project_file=$(ls *.xpr)

# Does the project file exist?
if [ -z "$project_file" ]; then
   echo "No Vivado project found"
   exit 1
fi

# Clean up existing Vivado log/journal cruft
rm -rf vivado*\.log vivado*\.jou

# Determine the executable path to the correct version of Vivado
VIVADO=$(get_vivado $project_file)

# Get the base name of the project (without file extension)
project="${project_file%.*}"

# Create the names of the log files
synth_log=${project}.runs/synth_1/runme.log
impl_log=${project}.runs/impl_1/runme.log

# Make sure the log files don't exist
rm -rf $synth_log $impl_log

# Make sure that git_hash.vh contains the hash from the current commit
update_githash_file

# Kick off Vivado, which will run in the background
$VIVADO -mode batch -source vbuild.tcl

# Here we wait for sythesis to start
echo ">>> Waiting for synthesis to begin <<<"
while [ ! -f $synth_log ]; do
    sleep 1
done

# Here we continuously display the synth log and wait
# for it to indicate that synthesis is complete
while true; do
   sleep 1
   cat $synth_log
   grep -q "Exiting Vivado" $synth_log
   test $? -eq 0 && break
done


# Here we wait for implementation to start
echo ">>> Waiting for implementation to begin <<<"
while [ ! -f $impl_log ]; do
    sleep 1
done

# Here we continuously display the impl log and wait
# for it to indicate that the build is complete
while true; do
   sleep 1
   cat $impl_log
   grep -q "Exiting Vivado" $impl_log
   test $? -eq 0 && break
done


