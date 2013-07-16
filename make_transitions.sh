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
mkdir ${mydir}/${1}

## surfaces in freesurfer
## requires AFNI for the gifti_tool:
for HEMI in R L; do
	for SURF in pial inflated sphere midthickness; do
		cmd="gifti_tool -infiles ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.${HEMI}.${SURF}.32k_fs_LR.surf.gii -write_asc ${mydir}/${1}/${HEMI}.${SURF}.asc"
		echo $cmd
		$cmd
	done
	cmd="gifti_tool -infiles ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.${HEMI}.curvature.32k_fs_LR.shape.gii  -write_1D ${mydir}/${1}/${HEMI}.curvature.shape.1D"
	echo $cmd
	$cmd
done 

## Create connectivity matrices
for REST in REST1 REST2; do
	for PHASEDIR in RL LR; do
		cmd="$workbench -cifti-correlation ${datadir}/${1}/MNINonLinear/Results/rfMRI_${REST}_${PHASEDIR}/rfMRI_${REST}_${PHASEDIR}_Atlas.dtseries.nii \
			${mydir}/${1}/rfMRI_${REST}_${PHASEDIR}.dconn.nii -fisher-z"
		echo $cmd
		$cmd
	done
done
	
## Averaging across four runs
cmd="$workbench -cifti-average ${mydir}/${1}/rfMRI_REST_z.dconn.nii \
	-cifti ${mydir}/${1}/rfMRI_REST1_RL.dconn.nii \
	-cifti ${mydir}/${1}/rfMRI_REST1_LR.dconn.nii \
	-cifti ${mydir}/${1}/rfMRI_REST2_RL.dconn.nii \
	-cifti ${mydir}/${1}/rfMRI_REST2_LR.dconn.nii"
echo $cmd
$cmd	
	
## Transform r-to-z
$workbench -cifti-math ' tanh(z) ' ${mydir}/${1}/rfMRI_REST.dconn.nii \
	-fixnan 0 -var z ${mydir}/${1}/rfMRI_REST_z.dconn.nii

## Remove unnecessary and large corelation files
cmd="rm -f ${mydir}/${1}/rfMRI_REST_z.dconn.nii \
	${mydir}/${1}/rfMRI_REST1_RL.dconn.nii \
	${mydir}/${1}/rfMRI_REST1_LR.dconn.nii \
	${mydir}/${1}/rfMRI_REST2_RL.dconn.nii \
	${mydir}/${1}/rfMRI_REST2_LR.dconn.nii"
echo $cmd
$cmd

## Calculate gradient
cmd="$workbench -cifti-gradient ${mydir}/${1}/rfMRI_REST.dconn.nii ROW \
	${mydir}/${1}/rfMRI_gradient.dscalar.nii \
	-left-surface ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.L.midthickness.32k_fs_LR.surf.gii \
	-right-surface ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.R.midthickness.32k_fs_LR.surf.gii \
	-surface-presmooth ${ss} \
	-volume-presmooth ${vs}"
echo $cmd
$cmd

cmd="$workbench -cifti-separate ${mydir}/${1}/rfMRI_gradient.dscalar.nii COLUMN \
	-metric CORTEX_LEFT ${mydir}/${1}/rfMRI_gradient.L.metric \
	-metric CORTEX_RIGHT ${mydir}/${1}/rfMRI_gradient.R.metric"
echo $cmd
$cmd

for HEMI in L R; do
	cmd="$workbench -metric-convert -to-nifti \
		${mydir}/${1}/rfMRI_gradient.${HEMI}.metric \
		${mydir}/${1}/rfMRI_gradient.${HEMI}.nii"
	echo $cmd
	$cmd

	cmd="3dmaskdump -noijk ${mydir}/${1}/rfMRI_gradient.${HEMI}.nii \
		> ${mydir}/${1}/rfMRI_gradient.${HEMI}.1D"
	echo $cmd
	$cmd

	cmd="rm ${mydir}/${1}/rfMRI_gradient.${HEMI}.metric \
		${mydir}/${1}/rfMRI_gradient.${HEMI}.nii "
	echo $cmd
	$cmd
done

## Calculate gradient of gradient	
cmd="$workbench -cifti-gradient ${mydir}/${1}/rfMRI_gradient.dscalar.nii COLUMN \
	${mydir}/${1}/rfMRI_gradient2.dscalar.nii \
	-left-surface ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.L.midthickness.32k_fs_LR.surf.gii \
	-right-surface ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.R.midthickness.32k_fs_LR.surf.gii"
echo $cmd
$cmd

