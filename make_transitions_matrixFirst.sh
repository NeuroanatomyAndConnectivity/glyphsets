#!/bin/bash

## use as follows: make_transitions <HCP directory, e.g. 100307>
## creates new directory with:
## surfaces to freesurfer
## connectivity matrices & gradients

ss=4 	# surface-presmooth 
vs=4 	# volume-presmooth
se=10 	# surface-exclude 
ve=10   # volume-exclude
ml=40 	# mem-limit 


## this needs to point at the human connectome workbench commandline program
workbench=/scr/liberia1/connectome_wb/workbench/bin_linux64/wb_command

## this needs to point at the directory where the HCP data is
#release="q1 q2"
release=${2}
datadir=/a/documents/connectome/${release}

## the directory where the sets get created
mydir=/scr/kansas1/margulies/hcp
if [ ! -d ${mydir}/${1} ]; then
	mkdir ${mydir}/${1}
fi

## surfaces in freesurfer
## requires AFNI for the gifti_tool: 
for HEMI in R L; do
	for SURF in pial inflated sphere midthickness; do
		if [ ! -f ${mydir}/${1}/${HEMI}.${SURF}.asc ]; then
		cmd="gifti_tool -infiles ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.${HEMI}.${SURF}.32k_fs_LR.surf.gii -write_asc ${mydir}/${1}/${HEMI}.${SURF}.asc"
		echo $cmd; $cmd; fi
	done
	for SHAPE in sulc curvature corrThickness thickness; do
		if [ ! -f ${mydir}/${1}/${HEMI}.${SHAPE}.shape.1D ]; then 
		cmd="gifti_tool -infiles \
			${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.${HEMI}.${SHAPE}.32k_fs_LR.shape.gii  \
			-write_1D ${mydir}/${1}/${HEMI}.${SHAPE}.shape.1D"
		echo $cmd; $cmd; fi
	done
done 

## Create connectivity matrices
if [ ! -f ${mydir}/${1}/rfMRI_gradient.dscalar.nii ]; then
for REST in REST1 REST2; do
for PHASE in RL LR; do
	for HEMI in LEFT RIGHT; do
		## Preprocessing:
		# cifti -> metric
		if [ ! -f ${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.gii ]; then 
		cmd="$workbench -cifti-separate \
			${datadir}/${1}/MNINonLinear/Results/rfMRI_${REST}_${PHASE}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.nii \
			COLUMN \
			-metric CORTEX_${HEMI} \
			${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.gii"
		echo $cmd; $cmd; fi
		# metric -> nifti
		if [ ! -f ${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.nii ]; then 
		cmd="$workbench -metric-convert -to-nifti \
			${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.gii \
			${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.nii"
		echo $cmd; $cmd; fi
		# regress out movement and bandpass filter
		if [ ! -f ${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.preproc.nii ]; then 
		cp ${datadir}/${1}/MNINonLinear/Results/rfMRI_${REST}_${PHASE}/Movement_Regressors.txt \
			${mydir}/${1}/rfMRI_${REST}_${PHASE}_Movement_Regressors.1D
		cp ${datadir}/${1}/MNINonLinear/Results/rfMRI_${REST}_${PHASE}/Movement_Regressors_dt.txt \
			${mydir}/${1}/rfMRI_${REST}_${PHASE}_Movement_Regressors_dt.1D
		cmd="3dBandpass -ort ${mydir}/${1}/rfMRI_${REST}_${PHASE}_Movement_Regressors.1D \
			-ort ${mydir}/${1}/rfMRI_${REST}_${PHASE}_Movement_Regressors.1D \
			-prefix ${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.preproc.1D \
			-dt 0.720 -band 0.01 0.1 \
			${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.nii"
		echo $cmd; $cmd
		cmd="3dAFNItoNIFTI -prefix ${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.preproc.nii \
			${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.preproc.1D"
		echo $cmd; $cmd; fi

		if [ ${HEMI}="LEFT" ]; then
			surfHEMI="L"
		elif [ ${HEMI}="RIGHT" ]; then
			surfHEMI="R" 
		fi
		# conversion back to metric
		if [ ! -f ${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.preproc.gii ]; then 
		cmd="$workbench -metric-convert -from-nifti \
			${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.preproc.nii \
			${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.${surfHEMI}.pial.32k_fs_LR.surf.gii \
			${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.preproc.gii"
		echo $cmd; $cmd; fi
	done

	# -> dense data series cifti
	if [ ! -f ${mydir}/${1}/rfMRI_${REST}_${PHASE}_preproc.dtseries.nii ]; then
	cmd="$workbench -cifti-create-dense-timeseries \
		${mydir}/${1}/rfMRI_${REST}_${PHASE}_preproc.dtseries.nii \
		-left-metric ${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.LEFT.metric.preproc.gii \
		-right-metric ${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.RIGHT.metric.preproc.gii"
	echo $cmd; $cmd; fi
	# Spatial smoothing at 4mm/2.355 = sigma
	if [ ! -f ${mydir}/${1}/rfMRI_${REST}_${PHASE}_preproc.ss.dtseries.nii ]; then
	sigmaSurf=1.699 #$((${ss}/2.3548))
	sigmaVol=1.699 #$((${vs}/2.3548))
	cmd="$workbench -cifti-smoothing ${mydir}/${1}/rfMRI_${REST}_${PHASE}_preproc.dtseries.nii \
		${sigmaSurf} ${sigmaVol} COLUMN \
		${mydir}/${1}/rfMRI_${REST}_${PHASE}_preproc.ss.dtseries.nii
		-left-surface ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.L.pial.32k_fs_LR.surf.gii \
		-right-surface ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.R.pial.32k_fs_LR.surf.gii \
		-fix-zeros-surface"
		#-fix-zeros-volume \
	echo $cmd; $cmd; fi

	if [ ! -f ${mydir}/${1}/rfMRI_REST.dconn.nii ]; then
	if [ ! -f ${mydir}/${1}/rfMRI_${REST}_${PHASE}.dconn.nii ]; then 
	cmd="$workbench -cifti-correlation \
		${mydir}/${1}/rfMRI_${REST}_${PHASE}_preproc.ss.dtseries.nii \
		${mydir}/${1}/rfMRI_${REST}_${PHASE}.dconn.nii \
		-fisher-z \
		-mem-limit ${ml}"
		#-roi-override
		#-left-roi ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.L.atlasroi.32k_fs_LR.shape.gii \
		#-right-roi ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.R.atlasroi.32k_fs_LR.shape.gii \
		
	echo $cmd; $cmd; fi; fi
done
done

## Averaging across four runs
if [ ! -f ${mydir}/${1}/rfMRI_REST.dconn.nii ]; then
if [ ! -f ${mydir}/${1}/rfMRI_REST_z_dconn.nii ]; then 
cmd="$workbench -cifti-average ${mydir}/${1}/rfMRI_REST_z.dconn.nii \
	-cifti ${mydir}/${1}/rfMRI_REST1_RL.dconn.nii \
	-cifti ${mydir}/${1}/rfMRI_REST1_LR.dconn.nii \
	-cifti ${mydir}/${1}/rfMRI_REST2_RL.dconn.nii \
	-cifti ${mydir}/${1}/rfMRI_REST2_LR.dconn.nii"
echo $cmd; $cmd; fi; fi

## Transform r-to-z
if [ ! -f ${mydir}/${1}/rfMRI_REST.dconn.nii ]; then 
$workbench -cifti-math 'tanh(z)' ${mydir}/${1}/rfMRI_REST.dconn.nii \
	-fixnan 0 -var z ${mydir}/${1}/rfMRI_REST_z.dconn.nii 
fi

## Calculate gradient
if [ ! -f ${mydir}/${1}/rfMRI_gradient.dscalar.nii ]; then 
cmd="$workbench -cifti-gradient ${mydir}/${1}/rfMRI_REST.dconn.nii ROW ${mydir}/${1}/rfMRI_gradient.dscalar.nii \
	-left-surface ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.L.midthickness.32k_fs_LR.surf.gii \
	-right-surface ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.R.midthickness.32k_fs_LR.surf.gii \
	-surface-presmooth ${ss} \
	-volume-presmooth ${vs} \
	-average-output"
echo $cmd; $cmd; fi

# Export gradient results
if [ ! -f ${mydir}/${1}/rfMRI_gradient.R.dconn.nii ]; then 
cmd="$workbench -cifti-separate ${mydir}/${1}/rfMRI_gradient.dscalar.nii COLUMN \
	-metric CORTEX_LEFT ${mydir}/${1}/rfMRI_gradient.L.metric \
	-metric CORTEX_RIGHT ${mydir}/${1}/rfMRI_gradient.R.metric"
echo $cmd; $cmd; fi

fi
## above is end of basic query...
##############################################
for HEMI in L R; do
	if [ ! -f ${mydir}/${1}/rfMRI_gradient.${HEMI}.nii ]; then 
	cmd="$workbench -metric-convert -to-nifti \
		${mydir}/${1}/rfMRI_gradient.${HEMI}.metric \
		${mydir}/${1}/rfMRI_gradient.${HEMI}.nii"
	echo $cmd; $cmd; fi
	if [ ! -f ${mydir}/${1}/rfMRI_gradient.${HEMI}.1D ]; then 
	3dmaskdump -noijk ${mydir}/${1}/rfMRI_gradient.${HEMI}.nii >${mydir}/${1}/rfMRI_gradient.${HEMI}.1D
	cmd="rm ${mydir}/${1}/rfMRI_gradient.${HEMI}.metric"
	echo $cmd; $cmd; fi
done

## Calculate gradient of gradient
if [ ! -f ${mydir}/${1}/rfMRI_gradient2.dscalar.nii ]; then
cmd="$workbench -cifti-gradient ${mydir}/${1}/rfMRI_gradient.dscalar.nii COLUMN ${mydir}/${1}/rfMRI_gradient2.dscalar.nii\
	-left-surface ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.L.midthickness.32k_fs_LR.surf.gii \
	-right-surface ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.R.midthickness.32k_fs_LR.surf.gii \
	-surface-presmooth ${ss}"
echo $cmd; $cmd; fi

# Export gradient-of-gradient results
if [ ! -f ${mydir}/${1}/rfMRI_gradient2.L.dconn.nii ]; then 
cmd="$workbench -cifti-separate ${mydir}/${1}/rfMRI_gradient2.dscalar.nii COLUMN \
	-metric CORTEX_LEFT ${mydir}/${1}/rfMRI_gradient2.L.metric \
	-metric CORTEX_RIGHT ${mydir}/${1}/rfMRI_gradient2.R.metric"
echo $cmd; $cmd; fi

for HEMI in L R; do
	if [ ! -f ${mydir}/${1}/rfMRI_gradient2.${HEMI}.nii ]; then 
	cmd="$workbench -metric-convert -to-nifti \
		${mydir}/${1}/rfMRI_gradient2.${HEMI}.metric \
		${mydir}/${1}/rfMRI_gradient2.${HEMI}.nii"
	echo $cmd; $cmd; fi
	if [ ! -f ${mydir}/${1}/rfMRI_gradient2.${HEMI}.1D ]; then 
	3dmaskdump -noijk ${mydir}/${1}/rfMRI_gradient2.${HEMI}.nii >${mydir}/${1}/rfMRI_gradient2.${HEMI}.1D
	cmd="rm ${mydir}/${1}/rfMRI_gradient2.${HEMI}.metric"
	echo $cmd; $cmd; fi
done

## Clean up unnecessary files:
if [ -f ${mydir}/${1}/rfMRI_REST.dconn.nii ]; then
cmd="rm -f ${mydir}/${1}/rfMRI_REST_z.dconn.nii \
	${mydir}/${1}/rfMRI_REST?_??.dconn.nii \
	${mydir}/${1}/rfMRI_REST?_??_Atlas.dtseries.*.metric.*"
echo $cmd; $cmd; fi
#if [ -f ${mydir}/${1}/rfMRI_gradient.dscalar.nii ]; then
#cmd="rm -f ${mydir}/${1}/rfMRI_REST.dconn.nii"
#echo $cmd; $cmd; fi

