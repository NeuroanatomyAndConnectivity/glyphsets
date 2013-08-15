#!/bin/sh
## use as follows: make_transitions <HCP directory, e.g. 100307>
## creates new directory with:
## surfaces to freesurfer
## connectivity matrices & gradients

ss=4 	# surface-presmooth 
vs=4 	# volume-presmooth
se=10 	# surface-exclude 
ve=10   # volume-exclude
ml=80 	# mem-limit
subName=${1}

## this needs to point at the human connectome workbench commandline program
workbench=/SCR/connectome_wb/workbench/bin_linux64/wb_command

## this needs to point at the directory where the HCP data is
datadir=/a/documents/gorgolewski

## the directory where the sets get created
mydir=/SCR/margulies/hcp
mkdir ${mydir}/${subName}

## surfaces in freesurfer
## requires AFNI for the gifti_tool:
for HEMI in R L; do
	for SURF in pial inflated sphere midthickness; do
		cmd="gifti_tool -infiles ${datadir}/${subName}/MNINonLinear/fsaverage_LR32k/${subName}.${HEMI}.${SURF}.32k_fs_LR.surf.gii -write_asc ${mydir}/${subName}/${HEMI}.${SURF}.asc"
		echo $cmd
		$cmd
	done
	for SHAPE in culc curvature corrThickness thickness; do
		cmd="gifti_tool -infiles \
			${datadir}/${subName}/MNINonLinear/fsaverage_LR32k/${subName}.${HEMI}.${SHAPE}.32k_fs_LR.shape.gii  \
			-write_1D ${mydir}/${subName}/${HEMI}.${SHAPE}.shape.1D"
		echo $cmd
		$cmd
	done
done 

## Create connectivity matrices
for REST in REST1 REST2; do
	for PHASEDIR in RL LR; do
	## Calculate gradient
	cmd="$workbench -cifti-correlation-gradient \
		${datadir}/${subName}/MNINonLinear/Results/rfMRI_${REST}_${PHASEDIR}/rfMRI_${REST}_${PHASEDIR}_Atlas.dtseries.nii \
		${mydir}/${subName}/rfMRI_${REST}_${PHASEDIR}_gradient.dscalar.nii \
		-left-surface ${datadir}/${subName}/MNINonLinear/fsaverage_LR32k/${subName}.L.midthickness.32k_fs_LR.surf.gii \
		-right-surface ${datadir}/${subName}/MNINonLinear/fsaverage_LR32k/${subName}.R.midthickness.32k_fs_LR.surf.gii \
		-surface-presmooth ${ss} \
		-volume-presmooth ${vs} \
		-surface-exclude ${se} \
		-volume-exclude ${ve} \
		-mem-limit ${ml}"
	echo $cmd
	$cmd
	done
done

## Averaging across four gradients
cmd="$workbench -cifti-average ${mydir}/${subName}/rfMRI_gradient.dscalar.nii \
	-cifti ${mydir}/${subName}/rfMRI_REST1_RL_gradient.dscalar.nii \
	-cifti ${mydir}/${subName}/rfMRI_REST1_LR_gradient.dscalar.nii \
	-cifti ${mydir}/${subName}/rfMRI_REST2_RL_gradient.dscalar.nii \
	-cifti ${mydir}/${subName}/rfMRI_REST2_LR_gradient.dscalar.nii"
echo $cmd
$cmd

# Export gradient results
cmd="$workbench -cifti-separate ${mydir}/${subName}/rfMRI_gradient.dscalar.nii COLUMN \
	-metric CORTEX_LEFT ${mydir}/${subName}/rfMRI_gradient.L.metric \
	-metric CORTEX_RIGHT ${mydir}/${subName}/rfMRI_gradient.R.metric"
echo $cmd
$cmd

for HEMI in L R; do
	cmd="$workbench -metric-convert -to-nifti \
		${mydir}/${subName}/rfMRI_gradient.${HEMI}.metric \
		${mydir}/${subName}/rfMRI_gradient.${HEMI}.nii"
	echo $cmd
	$cmd

	cmd="3dmaskdump -noijk ${mydir}/${subName}/rfMRI_gradient.${HEMI}.nii \
		> ${mydir}/${subName}/rfMRI_gradient.${HEMI}.1D"
	echo $cmd
	$cmd

	cmd="rm ${mydir}/${subName}/rfMRI_gradient.${HEMI}.metric"
	echo $cmd
	$cmd
done



