#!/bin/sh

# human connectome workbench commandline program
workbench=/scr/murg1/workbench/bin_linux64/wb_command

sub=${1} #subject ID
datadir=${2} #location of HCP data
workdir=${3} #where you want the results

ss=0.1 #surface smoothing kernel in mm
vs=0.1 #volume smoothing kernel in mm

#calculate gradient of myelin map and apply smoothing
cmd="$workbench -cifti-gradient ${datadir}/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.MyelinMap_BC.32k_fs_LR.dscalar.nii COLUMN ${workdir}/${sub}/MyelinMap_gradient_LR.${ss}mm.dscalar.nii \
-left-surface ${datadir}/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.L.midthickness.32k_fs_LR.surf.gii \
-right-surface ${datadir}/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.R.midthickness.32k_fs_LR.surf.gii \
-surface-presmooth ${ss} \
-volume-presmooth ${vs} \
-average-output"
echo $cmd
$cmd

for HEMI in LEFT RIGHT; do
	#separate hemispheres and save as metric
	cmd="$workbench -cifti-separate ${workdir}/${sub}/MyelinMap_gradient_LR.${ss}mm.dscalar.nii COLUMN \
	-metric CORTEX_${HEMI} \
	${workdir}/${sub}/MyelinMap_gradient.${HEMI}.metric"
	echo $cmd
	$cmd
	#convert metric to nifti
	cmd="$workbench -metric-convert -to-nifti ${workdir}/${sub}/MyelinMap_gradient.${HEMI}.metric ${workdir}/${sub}/MyelinMap_gradient.${HEMI}.nii"
	echo $cmd
	$cmd
	#convert nifti to 1D - AFNI command
	cmd="3dmaskdump -noijk -o ${workdir}/${sub}/MyelinMap_gradient.${ss}mm.${HEMI}.1D ${workdir}/${sub}/MyelinMap_gradient.${HEMI}.nii"
	echo $cmd
	$cmd
	rm ${workdir}/${sub}/MyelinMap_gradient.${HEMI}.metric
	rm ${workdir}/${sub}/MyelinMap_gradient.${HEMI}.nii
done
