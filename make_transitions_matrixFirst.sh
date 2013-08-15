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

## this needs to point at the human connectome workbench commandline program
workbench=/scr/liberia1/connectome_wb/workbench/bin_linux64/wb_command

## this needs to point at the directory where the HCP data is
#release="q1 q2"
release=${2}
datadir=/a/documents/connectome/${release}

## the directory where the sets get created
mydir=/SCR/margulies/hcp
mkdir ${mydir}/${1}

## surfaces in freesurfer
## requires AFNI for the gifti_tool: 
for HEMI in R L; do
	for SURF in pial inflated sphere midthickness; do
		cmd="gifti_tool -infiles ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.${HEMI}.${SURF}.32k_fs_LR.surf.gii -write_asc ${mydir}/${1}/${HEMI}.${SURF}.asc"
		echo $cmd; $cmd
	done
	for SHAPE in culc curvature corrThickness thickness; do
		cmd="gifti_tool -infiles \
			${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.${HEMI}.${SHAPE}.32k_fs_LR.shape.gii  \
			-write_1D ${mydir}/${1}/${HEMI}.${SHAPE}.shape.1D"
		echo $cmd; $cmd
	done
done 

## Create connectivity matrices
for REST in REST1 REST2; do
for PHASE in RL LR; do
	for HEMI in LEFT RIGHT; do
		s## Preprocessing:
		# cifti -> metric
		if [ -a ${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.gii ]; then; else
		cmd="$workbench -cifti-separate \
			${datadir}/${1}/MNINonLinear/Results/rfMRI_${REST}_${PHASE}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.nii \
			COLUMN \
			-metric CORTEX_${HEMI} \
			${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.gii"
		echo $cmd; $cmd; fi
		# metric -> nifti
		if [ -a ${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.nii ]; then; else
		cmd="$workbench -metric-convert -to-nifti \
			${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.gii \
			${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.nii"
		echo $cmd; $cmd; fi

		# regress out movement (6 DOF and derivatives)
		if [ -a ${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.res.1D ]; then; else
		cmd="3dDetrend \
			-prefix ${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.res.1D  \
			-vector ${datadir}/${1}/MNINonLinear/Results/rfMRI_${REST}_${PHASE}/Movement_Regressors.txt \
			-polort 1 \
			${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.nii"
		echo $cmd; $cmd; fi
			# -vector ${datadir}/${1}/MNINonLinear/Results/rfMRI_${REST}_${PHASE}/Movement_Regressors_dt.txt \
			# -vector ${datadir}/${1}/MNINonLinear/Results/rfMRI_${REST}_${PHASE}/rfMRI_${REST}_${PHASE}_Physio_log.txt[1,2] \

		# 3DDetrend seems to write 1D files, regardless of .nii file endings, therefore:
		if [ -a ${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.res.1D.nii ]; then; else
		cmd="3dAFNItoNIFTI \
			-prefix ${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.res.1D.nii
			${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.res.1D"
		echo $cmd; $cmd; fi

		# whatever preprocessing can be done on NIFTI timeseries files goes here:
		# bandpass filtering: values are in TRs (.6s), 166 is 0.01, 20 is 0.08:
		if [ -a ${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.res.bp.nii.gz ]; then; else
		cmd="fslmaths \
			${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.res.1D.nii \
			-bptf 166 20 \
			${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.res.bp.nii.gz"
		echo $cmd; $cmd; fi

		if [ ${HEMI}="LEFT" ]; then
			surfHEMI="L"
		elif [ ${HEMI}="RIGHT" ]; then
			surfHEMI="R" 
		fi
		# conversion back to metric
		if [ -a ${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.res.bp.gii ]; then; else
		cmd="$workbench -metric-convert -from-nifti \
			${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.res.bp.nii.gz \
			${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.${surfHEMI}.pial.32k_fs_LR.surf.gii \
			${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.res.bp.gii"
		echo $cmd; $cmd; fi
	done

	# -> dense data series cifti
	if [ -a ${mydir}/${1}/rfMRI_${REST}_${PHASE}_preproc.dtseries.nii ]; then; else
	cmd="$workbench -cifti-create-dense-timeseries \
		${mydir}/${1}/rfMRI_${REST}_${PHASE}_preproc.dtseries.nii \
		-left-metric ${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.LEFT.metric.res.bp.gii \
		-right-metric ${mydir}/${1}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.RIGHT.metric.res.bp.gii"
	echo $cmd; $cmd; fi
	if [ -a ${mydir}/${1}/rfMRI_${REST}_${PHASE}.dconn.nii ]; then; else
	cmd="$workbench -cifti-correlation \
		${mydir}/${1}/rfMRI_${REST}_${PHASE}_preproc.dtseries.nii \
		${mydir}/${1}/rfMRI_${REST}_${PHASE}.dconn.nii \
		-roi-override
		-left-roi ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.L.atlasroi.32k_fs_LR.shape.gii \
		-right-roi ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.R.atlasroi.32k_fs_LR.shape.gii \
		-fisher-z \
		-mem-limit ${ml}"
	echo $cmd; $cmd; fi
done
done

## Averaging across four runs
if [ -a ${mydir}/${1}/rfMRI_REST_z_dconn.nii ]; then; else
cmd="$workbench -cifti-average ${mydir}/${1}/rfMRI_REST_z.dconn.nii \
	-cifti ${mydir}/${1}/rfMRI_REST1_RL.dconn.nii \
	-cifti ${mydir}/${1}/rfMRI_REST1_LR.dconn.nii \
	-cifti ${mydir}/${1}/rfMRI_REST2_RL.dconn.nii \
	-cifti ${mydir}/${1}/rfMRI_REST2_LR.dconn.nii"
echo $cmd; $cmd; fi

## Transform r-to-z
if [ -a ${mydir}/${1}/rfMRI_REST.dconn.nii ]; then; else
$workbench -cifti-math 'tanh(z)' ${mydir}/${1}/rfMRI_REST.dconn.nii \
	-fixnan 0 -var z ${mydir}/${1}/rfMRI_REST_z.dconn.nii 
fi

## Calculate gradient
if [ -a ${mydir}/${1}/rfMRI_gradient.dscalar.nii ]; then; else
cmd="$workbench -cifti-gradient ${mydir}/${1}/rfMRI_REST.dconn.nii ROW ${mydir}/${1}/rfMRI_gradient.dscalar.nii \
	-left-surface ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.L.midthickness.32k_fs_LR.surf.gii \
	-right-surface ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.R.midthickness.32k_fs_LR.surf.gii \
	-surface-presmooth ${ss} \
	-average-output"
echo $cmd; $cmd; fi

# Export gradient results
if [ -a ${mydir}/${1}/rfMRI_gradient.L.dconn.nii ]; then; else
cmd="$workbench -cifti-separate ${mydir}/${1}/rfMRI_gradient.dscalar.nii COLUMN \
	-metric CORTEX_LEFT ${mydir}/${1}/rfMRI_gradient.L.metric \
	-metric CORTEX_RIGHT ${mydir}/${1}/rfMRI_gradient.R.metric"
echo $cmd; $cmd; fi

for HEMI in L R; do
	if [ -a ${mydir}/${1}/rfMRI_gradient.${HEMI}.nii ]; then; else
	cmd="$workbench -metric-convert -to-nifti \
		${mydir}/${1}/rfMRI_gradient.${HEMI}.metric \
		${mydir}/${1}/rfMRI_gradient.${HEMI}.nii"
	echo $cmd; $cmd; fi
	if [ -a ${mydir}/${1}/rfMRI_gradient.${HEMI}.1D ]; then; else
	cmd="3dmaskdump -noijk ${mydir}/${1}/rfMRI_gradient.${HEMI}.nii \
		> ${mydir}/${1}/rfMRI_gradient.${HEMI}.1D"
	echo $cmd; $cmd; fi
	cmd="rm ${mydir}/${1}/rfMRI_gradient.${HEMI}.metric"
	echo $cmd; $cmd
done

## Calculate gradient of gradient
if [ -a ${mydir}/${1}/rfMRI_gradient2.dscalar.nii ]; then; else
cmd="$workbench -cifti-gradient ${mydir}/${1}/rfMRI_gradient.dscalar.nii COLUMN ${mydir}/${1}/rfMRI_gradient2.dscalar.nii\
	-left-surface ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.L.midthickness.32k_fs_LR.surf.gii \
	-right-surface ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.R.midthickness.32k_fs_LR.surf.gii \
	-surface-presmooth ${ss}"
echo $cmd; $cmd; fi

# Export gradient-of-gradient results
if [ -a ${mydir}/${1}/rfMRI_gradient2.L.dconn.nii ]; then; else
cmd="$workbench -cifti-separate ${mydir}/${1}/rfMRI_gradient2.dscalar.nii COLUMN \
	-metric CORTEX_LEFT ${mydir}/${1}/rfMRI_gradient2.L.metric \
	-metric CORTEX_RIGHT ${mydir}/${1}/rfMRI_gradient2.R.metric"
echo $cmd; $cmd; fi

for HEMI in L R; do
	if [ -a ${mydir}/${1}/rfMRI_gradient2.${HEMI}.nii ]; then; else
	cmd="$workbench -metric-convert -to-nifti \
		${mydir}/${1}/rfMRI_gradient2.${HEMI}.metric \
		${mydir}/${1}/rfMRI_gradient2.${HEMI}.nii"
	echo $cmd; $cmd; fi
	if [ -a ${mydir}/${1}/rfMRI_gradient2.${HEMI}.1D ]; then; else
	cmd="3dmaskdump -noijk ${mydir}/${1}/rfMRI_gradient2.${HEMI}.nii \
		> ${mydir}/${1}/rfMRI_gradient2.${HEMI}.1D"
	echo $cmd; $cmd
	cmd="rm ${mydir}/${1}/rfMRI_gradient2.${HEMI}.metric"
	echo $cmd; $cmd; fi
done

## Clean up unnecessary files:
if [ -a ${mydir}/${1}/rfMRI_REST.dconn.nii ]; then
cmd="rm -f ${mydir}/${1}/rfMRI_REST_z.dconn.nii \
	${mydir}/${1}/rfMRI_REST?_??.dconn.nii \
	${mydir}/${1}/rfMRI_REST?_??_Atlas.dtseries.*.metric.*"
echo $cmd; $cmd; else; fi

