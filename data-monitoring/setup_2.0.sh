#!/bin/bash
# A script to set up data monitoring & preprocessing in your project
# TODO: Hallmonitor2.sub needs to be included in the git repo
usage() { echo "Usage: setup.sh [-t] [-c] <project-name>" 1>&2; exit 1; }

datam_path="data-monitoring"
code_path="code"
labpath="/home/data/NDClab/tools/lab-devOps/scripts/monitor"
MADE_path="/home/data/NDClab/tools/lab-devOps/scripts/MADE_pipeline_standard"
datapath="/home/data/NDClab/datasets"
sing_image="/home/data/NDClab/tools/instruments/containers/singularity/inst-container.simg"
cd $datapath

module load miniconda3-4.5.11-gcc-8.2.0-oqs2mbg # needed for pandas

#include ndc colors
c1=$'\033[95m'
c2=$'\033[93m'
c3=$'\033[33m'
#c4=$'\033[34m'
c4=$'\033[94m'
c5=$'\033[92m'
ENDC=$'\033[0m'
cat <<EOF
 ${c1}.__   __.${ENDC}  ${c2}_______${ENDC}   ${c3}______${ENDC}  ${c4}__${ENDC}          ${c5}___${ENDC}      ${c2}.______${ENDC}
 ${c1}|  \ |  |${ENDC} ${c2}|       \\${ENDC} ${c3}/      |${ENDC}${c4}|  |${ENDC}        ${c5}/   \\${ENDC}     ${c2}|   _  \\${ENDC}
 ${c1}|   \|  |${ENDC} ${c2}|  .--.${ENDC}  ${c3}|  ,----'${ENDC}${c4}|  |${ENDC}       ${c5}/  ^  \\${ENDC}    ${c2}|  |_)  |${ENDC}
 ${c1}|  . \`  |${ENDC} ${c2}|  |  |${ENDC}  ${c3}|  |${ENDC}     ${c4}|  |${ENDC}      ${c5}/  /_\  \\${ENDC}   ${c2}|   _  <${ENDC}
 ${c1}|  |\   |${ENDC} ${c2}|  '--'${ENDC}  ${c3}|  \`----.${ENDC}${c4}|  \`----.${ENDC}${c5}/  _____  \\${ENDC}  ${c2}|  |_)  |${ENDC}
 ${c1}|__| \__|${ENDC} ${c2}|_______/${ENDC} ${c3}\______|${ENDC}${c4}|_______${ENDC}${c5}/__/     \__\\${ENDC} ${c2}|______/${ENDC}
EOF

echo -e "data monitoring setting up ... \\n"
sleep 2

# interpret optional t flag to construct tracker

while getopts "tf:" opt; do
  case "${opt}" in
    t)
      gen_tracker=true
      ;;
    f)
      extra_flags="$OPTARG"
      ;;
    *)
      usage
      ;;
  esac
done
[[ -z $extra_flags ]] && extra_flags=""


#set the project name
shift $((OPTIND-1))
project=$1
[[ -z "${project}" ]] && usage
dataset="/home/data/NDClab/datasets/${project}"
[[ ! -d "${dataset}" ]] && echo "Project ${project} does not exist in ${datapath}" && exit 1

# get all redcap files in the project
source $labpath/tools.sh
rc_dirs=$(find $raw -type d -name "redcap")
rc_arr=()
for subdir in ${rc_dirs}; do
    redcaps=($(get_new_redcaps $subdir))
    for filename in ${redcaps[@]}; do
        rc_arr+=($subdir/$filename)
    done
done
all_redcaps=$(echo ${rc_arr[*]} | sed 's/ /,/g')

# sets up central tracker if -t flag is used
if [[ $gen_tracker == true ]]; then
    echo -e "Setting up central tracker... \\n"
    module load singularity-3.8.2
    singularity exec --bind /home/data/NDClab/tools/lab-devOps $sing_image python3 "${labpath}/gen-tracker.py" "${project}/${datam_path}/central-tracker_${project}.csv" $project $all_redcaps
    echo "Set up central tracker"
    ls -lh "${project}/${datam_path}/central-tracker_${project}.csv"
    chmod +x "${project}/${datam_path}/central-tracker_${project}.csv"
fi

echo -e "Copying necessary files ... \\n"

cp "${MADE_path}/subjects_yet_to_process.py" "${project}/${datam_path}"
cp "${MADE_path}/update-tracker-postMADE.py" "${project}/${datam_path}"
cp "${MADE_path}/MADE_pipeline.m" "${project}/${code_path}"

# give permissions for all copied files
chmod +x "${project}/${datam_path}/subjects_yet_to_process.py"
chmod +x "${project}/${datam_path}/update-tracker-postMADE.py"
chmod +x "${project}/${code_path}/MADE_pipeline.m"

echo -e "Setting up hallMonitor2.sub ... \\n"

if [ -f "${project}/${datam_path}/hallMonitor2.sub" ]; then
    #rm -f "${project}/${datam_path}/hallMonitor2.sub"
    echo "hallMonitor2.sub already exists, skipping copy"
fi

# sets up hallMonitor sub file without any default mapping or replacement
#cp "${labpath}/template/hallMonitor2.sub" "${project}/${datam_path}"

# give permissions for all copied files
chmod +x "${project}/${datam_path}/hallMonitor2.sub"

# set the dataset and extra flags in hallMonitor2.sub
hallMonitor_path="${project}/${datam_path}/hallMonitor2.sub"
echo "these are the flags ${extra_flags}"
sed -i "s|^DATASET=.*|DATASET=\"$dataset\"|" "$hallMonitor_path"
sed -i "s|^EXTRA_FLAGS=.*|EXTRA_FLAGS=\"$extra_flags\"|" "$hallMonitor_path"


echo -e "Setting up preprocess.sub ... \\n"
# delete if previously written
if [ -f "${project}/${datam_path}/preprocess.sub" ]; then
    rm -f "${project}/${datam_path}/preprocess.sub"
    rm -f "${project}/${datam_path}/preprocess_wrapper.sh"
fi
cp "${labpath}/template/preprocess.sub" "${project}/${datam_path}"
cp "${labpath}/template/preprocess_wrapper.sh" "${project}/${datam_path}"


# give permissions for all copied files
chmod +x "${project}/${datam_path}/preprocess.sub"
chmod +x "${project}/${datam_path}/preprocess_wrapper.sh"

echo -e "\\n [---Setup complete!---] \\n"
