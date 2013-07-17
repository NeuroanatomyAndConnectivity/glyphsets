#!/bin/sh
## use as follows: make_transitions <HCP directory, e.g. 100307>
## creates new directory with:
## surfaces to freesurfer
## connectivity matrices & gradients

ss=3 	# surface-presmooth 
vs=3 	# volume-presmooth
se=10 	# surface-exclude  
ml=80 	# mem-limit 


## this needs to point at the human connectome workbench commandline program
workbench=/SCR/connectome_wb/workbench/bin_linux64/wb_command

## this needs to point at the directory where the HCP data is
datadir=/a/documents/gorgolewski

## the directory where the sets get created
mydir=/SCR/margulies/hcp


##################################################################################################################
## Approach #3:

for REST in REST1 REST2; do
	for PHASEDIR in RL LR; do

	cmd="$workbench \
	-cifti-correlation-gradient ${datadir}/${1}/MNINonLinear/Results/rfMRI_${REST}_${PHASEDIR}/rfMRI_${REST}_${PHASEDIR}_Atlas.dtseries.nii ${mydir}/${1}/rfMRI_gradient_${REST}_${PHASEDIR}.dscalar.nii \
	-left-surface ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.L.midthickness.32k_fs_LR.surf.gii \
	-right-surface ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.R.midthickness.32k_fs_LR.surf.gii \
	-surface-presmooth ${ss} \
	-volume-presmooth ${vs} \
	-surface-exclude ${se} \
	-mem-limit ${ml}"
echo $cmd
$cmd
	done
done

cmd="$workbench -cifti-average ${mydir}/${1}/rfMRI_gradient_avg.dscalar.nii  \
	-cifti ${mydir}/${1}/rfMRI_gradient_REST1_LR.dscalar.nii \
	-cifti ${mydir}/${1}/rfMRI_gradient_REST1_RL.dscalar.nii \
	-cifti ${mydir}/${1}/rfMRI_gradient_REST2_LR.dscalar.nii \
	-cifti ${mydir}/${1}/rfMRI_gradient_REST2_RL.dscalar.nii"
echo $cmd
$cmd	

