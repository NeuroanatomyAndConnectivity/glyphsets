#!/bin/sh
## use as follows: make_transitions <HCP directory, e.g. 100307>
## creates new directory with:
## surfaces to freesurfer
## connectivity matrices & gradients

ss=3 	# surface-presmooth 
vs=3 	# volume-presmooth
se=10 	# surface-exclude  
ml=10 	# mem-limit 

## this needs to point at the human connectome workbench commandline program
workbench=wb_command

## this needs to point at the directory where the HCP data is
datadir=/a/documents/gorgolewski

## the directory where the sets get created
mydir=/SCR2/data/hcp
mkdir ${mydir}/${1}

## surfaces in freesurfer
## requires AFNI for the gifti_tool:
for HEMI in R L; do
	for SURF in pial inflated very\ inflated sphere midthickness; do
		cmd="gifti_tool -infiles ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.${HEMI}.${SURF}.32k_fs_LR.surf.gii -write_asc ${mydir}/${1}/${HEMI}.${SURF}.asc"
		echo $cmd
		$cmd
	done
	cmd="gifti_tool -infiles ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.${HEMI}.curvature.32k_fs_LR.shape.gii  -write_asc ${mydir}/${1}/${HEMI}.curvature.shape.asc"
	echo $cmd
	$cmd
done 

## Create connectivity matrices
for REST in REST1 REST2; do
	for PHASEDIR in RL LR; do
		cmd="$workbench -cifti-correlation ${datadir}/${1}/MNINonLinear/Results/rfMRI_${REST}_${PHASEDIR}/rfMRI_${REST}_${PHASEDIR}_Atlas.dtseries.nii \
			${mydir}/${1}/rfMRI_${REST}_${PHASEDIR}.corr.nii -fisher-z"
		echo $cmd
		$cmd
	done
done
	
## Averaging across four runs
cmd="$workbench -cifti-average ${mydir}/${1}/rfMRI_REST_z.corr.nii \
	-cifti ${mydir}/${1}/rfMRI_REST1_RL.corr.nii \
	-cifti ${mydir}/${1}/rfMRI_REST1_LR.corr.nii \
	-cifti ${mydir}/${1}/rfMRI_REST2_RL.corr.nii \
	-cifti ${mydir}/${1}/rfMRI_REST2_LR.corr.nii"
echo $cmd
$cmd	
	
## Transform r-to-z
cmd="$workbench -cifti-math 'tanh(z)' ${mydir}/${1}/rfMRI_REST.corr.nii -var z ${mydir}/${1}/rfMRI_REST_z.corr.nii"
echo $cmd
$cmd
rm -f ${mydir}/${1}/rfMRI_REST_z.corr.nii

## Calculate gradient
cmd="$workbench -cifti-correlation-gradient ${mydir}/${1}/rfMRI_REST.corr.nii ${mydir}/${1}/rfMRI_gradient.dscalar.nii \
	-left-surface ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.L.midthickness.32k_fs_LR.surf.gii \
	-right-surface ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.R.midthickness.32k_fs_LR.surf.gii \
	-surface-presmooth ${ss} \
	-volume-presmooth #{vs} \
	-surface-exclude ${se} \
	-mem-limit {ml}"
echo $cmd
$cmd

## Calculate gradient of gradient	
cmd="$workbench -cifti-gradient ${mydir}/${1}/rfMRI_gradient.dscalar.nii COLUMN \
	${mydir}/${1}/rfMRI_gradient2.dscalar.nii \
	-left-surface ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.L.midthickness.32k_fs_LR.surf.gii \
	-right-surface ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.R.midthickness.32k_fs_LR.surf.gii \
	-mem-limit {ml}"
echo $cmd
$cmd

