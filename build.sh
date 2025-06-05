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


# Determine the name of the Vivado project file
project_file=$(ls *.xpr)

# Does the project file exist?
if [ -z "$project_file" ]; then
   echo "No Vivado project found"
   exit 1
fi

# Determine the executable path to the correct version of Vivado
VIVADO=$(get_vivado $project_file)

# Create the names of the log files
synth_log=${project}.runs/synth_1/runme.log
impl_log=${project}.runs/impl_1/runme.log

# Make sure the log files don't exist
rm -rf $synth_log $impl_log

# Kick off Vivado, which will run in the background
$VIVADO -mode batch -source vbuild.tcl

# Get the base name of the project
project="${project_file%.*}"

# Create the names of the log files
synth_log=${project}.runs/synth_1/runme.log
impl_log=${project}.runs/impl_1/runme.log

# Here we wait for sythesis to start
echo ">>> Waiting for synthesis to begin <<<"
while [ ! -f $synth_log ]; do
    sleep 1
done

# Here we continuously display the synth log and wait
# for it to indicate that synthesis is complete
while [ 1 -eq 1 ]; do
   sleep 1
   cat $log
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
while [ 1 -eq 1 ]; do
   sleep 1
   cat $impl_log
   grep -q "Exiting Vivado" $impl_log
   test $? -eq 0 && break
done



