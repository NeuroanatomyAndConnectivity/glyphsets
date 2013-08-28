#!/bin/sh
# use as follows: make_glyphsets3 <HCP directory, e.g. 100307>
# creates a new directory with:
# copy of anatomical background nifti
# surfaces in freesurfer format
# .set files for these surfaces: l, r
# connectivity matrices for l
# .glyphset files for l

# this needs to point at the human connectome workbench commandline program
workbench=/scr/litauen1/workbench_0.82/bin_linux64/wb_command
subName=${1}

# new line

# this needs to point at the directory where the HCP data is
datadir=/a/documents/gorgolewski



# the directory where the sets get created
glyphsets=${2}
mkdir ${glyphsets}/${subName}

# copy of anatomical background
cp ${datadir}/${subName}/T1w/T1w_acpc_dc_restore_brain.nii.gz ${glyphsets}/${subName}

# convert surfaces to freesurfer (requires AFNI for the gifti_tool)
# create .set files for these surfaces
# TODO: offsets from the anatomical NIFTI header
for HEMI in R L; do
	rm ${glyphsets}/${subName}/${HEMI}.set
	for SURF in pial inflated very_inflated sphere midthickness; do
		gifti_tool -infiles ${datadir}/${subName}/MNINonLinear/fsaverage_LR32k/${subName}.${HEMI}.${SURF}.32k_fs_LR.surf.gii -write_asc ${glyphsets}/${subName}/${HEMI}.${SURF}.asc
		echo ${HEMI}.${SURF}.asc >> ${glyphsets}/${subName}/${HEMI}.set
	done
done

# connectivity matrices (for left hemispheres only, until tested)

# for all four runs
for REST in REST1 REST2; do
	for PHASEDIR in RL LR; do

	# smoothing 
	#wb_command -cifti-smoothing <cifti> <surface-kernel> <volume-kernel> <direction> <cifti-out> [-left-surface] <surface> [-right-surface] <surface>
	cmd="$workbench -cifti-smoothing \
	${datadir}/${subName}/MNINonLinear/Results/rfMRI_${REST}_${PHASEDIR}/rfMRI_${REST}_${PHASEDIR}_Atlas.dtseries.nii \
	4 4 COLUMN \
	${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.nii \
	-left-surface ${datadir}/${subName}/MNINonLinear/fsaverage_LR32k/${subName}.L.very_inflated.32k_fs_LR.surf.gii \
	-right-surface ${datadir}/${subName}/MNINonLinear/fsaverage_LR32k/${subName}.R.very_inflated.32k_fs_LR.surf.gii"
	echo $cmd
	$cmd

	# cifti -> metric
	cmd="$workbench -cifti-separate \
	${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.nii \
	COLUMN \
	-metric CORTEX_LEFT \
	${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric.gii"
	echo $cmd
	$cmd

	# metric -> nifti
	cmd="$workbench -metric-convert -to-nifti \
	${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric.gii \
	${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric.nii"
	echo $cmd
	$cmd

	# whatever preprocessing can be done on NIFTI timeseries files goes here:
	# bandpass filtering: values are in TRs (.6s), 166 is 0.01, 20 is 0.08:
	cmd="fslmaths \
	${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric.nii \
	-bptf 166 20 \
	${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric.nii_bptf.nii.gz"
	echo $cmd
	$cmd

	# regress out movement (6 DOF and derivatives)
	cmd="3dDetrend \
	-prefix ${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric.nii_bptf_res.1D  \
	-vector ${datadir}/${subName}/MNINonLinear/Results/rfMRI_${REST}_${PHASEDIR}/Movement_Regressors_dt.txt \
	-polort 1 \
	${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric.nii_bptf.nii.gz"
	echo $cmd
	$cmd

	# 3DDetrend seems to write 1D files, regardless of .nii file endings, therefore:
	cmd="3dAFNItoNIFTI \
	-prefix ${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric.nii_bptf_res.1D.nii
	${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric.nii_bptf_res.1D"
	echo $cmd
	$cmd

	# conversion back to metric
	cmd="$workbench -metric-convert -from-nifti \
	${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric.nii_bptf_res.1D.nii \
	${datadir}/${subName}/MNINonLinear/fsaverage_LR32k/${subName}.L.pial.32k_fs_LR.surf.gii \
	${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric_detrended.gii"
	echo $cmd
	$cmd

	# -> dense data series cifti
	cmd="$workbench -cifti-create-dense-timeseries \
	${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_left_metric.dtseries.nii \
	-left-metric ${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric_detrended.gii"
	echo $cmd
	$cmd

	# -> correlation matrix cifti
	cmd="$workbench -cifti-correlation \
	${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_left_metric.dtseries.nii \
	${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_left_corr_z.nii -fisher-z"
	echo $cmd
	$cmd

	done
done

# averaging
cmd="$workbench -cifti-average \
${glyphsets}/${subName}/rfMRI_REST_left_corr_z.nii \
-cifti ${glyphsets}/${subName}/rfMRI_REST1_RL_left_corr_z.nii \
-cifti ${glyphsets}/${subName}/rfMRI_REST1_LR_left_corr_z.nii \
-cifti ${glyphsets}/${subName}/rfMRI_REST2_RL_left_corr_z.nii \
-cifti ${glyphsets}/${subName}/rfMRI_REST2_LR_left_corr_z.nii"
echo $cmd
$cmd

# Get rid of the big files
rm -rf ${glyphsets}/${subName}/rfMRI_REST1_RL_left_corr_z.nii
rm -rf ${glyphsets}/${subName}/rfMRI_REST1_LR_left_corr_z.nii
rm -rf ${glyphsets}/${subName}/rfMRI_REST2_RL_left_corr_z.nii
rm -rf ${glyphsets}/${subName}/rfMRI_REST2_LR_left_corr_z.nii

# back to r
$workbench -cifti-math 'tanh(z)' \
${glyphsets}/${subName}/rfMRI_REST_left_corr_avg.nii \
-var z ${glyphsets}/${subName}/rfMRI_REST_left_corr_z.nii


## converion to external binary gifti: header file + the binary matrix we want for braingl
#cmd="$workbench -cifti-convert -to-gifti-ext \
#${glyphsets}/${subName}/rfMRI_REST_left_corr_avg.nii \
#${glyphsets}/${subName}/rfMRI_REST_left_corr_avg.gii"
#echo $cmd
#$cmd

# .glyphset file l
# TODO: remove other unneccessary large files
rm ${glyphsets}/${subName}/L.glyphset -rf

#echo T1w_acpc_dc_restore_brain.nii.gz >> ${glyphsets}/${subName}/L.glyphset
#echo L.set >> ${glyphsets}/${subName}/L.glyphset
# TODO: ROI, shifts against anatomical?
#echo rfMRI_REST_left_corr_avg.gii.data 0.5 1.0 >> ${glyphsets}/${subName}/L.glyphset


####################################################################################
# calculate gradients
cp ${glyphsets}/${subName}/rfMRI_REST_left_corr_avg.nii ${glyphsets}/${subName}/rfMRI_REST_left_corr_avg.dconn.nii

$workbench -cifti-gradient ${glyphsets}/${subName}/rfMRI_REST_left_corr_avg.dconn.nii ROW \
	${glyphsets}/${subName}/rfMRI_REST_left_gradient.dscalar.nii \
	-left-surface ${datadir}/${subName}/MNINonLinear/fsaverage_LR32k/${subName}.L.midthickness.32k_fs_LR.surf.gii \
	-average-output
	

# Export gradient results
# If this doesn't work, try using ROW instead of COLUMN
cmd="$workbench -cifti-separate ${glyphsets}/${subName}/rfMRI_REST_left_gradient.dscalar.nii COLUMN \
	-metric CORTEX_LEFT ${glyphsets}/${subName}/${subName}_rfMRI_gradient.L.metric"
echo $cmd
$cmd

for HEMI in L; do
	cmd="$workbench -metric-convert -to-nifti \
		${glyphsets}/${subName}/${subName}_rfMRI_gradient.${HEMI}.metric \
		${glyphsets}/${subName}/${subName}_rfMRI_gradient.${HEMI}.nii"
	echo $cmd
	$cmd

	cmd="3dmaskdump -noijk ${glyphsets}/${subName}/rfMRI_gradient.${HEMI}.nii \
		> ${glyphsets}/${subName}/${subName}_rfMRI_gradient.${HEMI}.1D"
	echo $cmd
	$cmd

	cmd="rm ${glyphsets}/${subName}/${subName}_rfMRI_gradient.${HEMI}.metric"
	echo $cmd
	$cmd
done
