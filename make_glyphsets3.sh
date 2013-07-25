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

# this needs to point at the directory where the HCP data is
datadir=/a/documents/gorgolewski

# the directory where the sets get created
glyphsets=/scr/tantalum1/gradientBusiness/pilotDumpout
mkdir ${glyphsets}/$1

# copy of anatomical background
cp ${datadir}/$1/T1w/T1w_acpc_dc_restore_brain.nii.gz ${glyphsets}/$1

# convert surfaces to freesurfer (requires AFNI for the gifti_tool)
# create .set files for these surfaces
# TODO: offsets from the anatomical NIFTI header
for HEMI in R L; do
	rm ${glyphsets}/$1/${HEMI}.set
	for SURF in pial inflated very_inflated sphere midthickness; do
		gifti_tool -infiles ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.${HEMI}.${SURF}.32k_fs_LR.surf.gii -write_asc ${glyphsets}/$1/${HEMI}.${SURF}.asc
		echo ${HEMI}.${SURF}.asc >> ${glyphsets}/$1/${HEMI}.set
	done
done

# connectivity matrices (for left hemispheres only, until tested)

# for all four runs
for REST in REST1 REST2; do
	for PHASEDIR in RL LR; do

	# smoothing 
	#wb_command -cifti-smoothing <cifti> <surface-kernel> <volume-kernel> <direction> <cifti-out> [-left-surface] <surface> [-right-surface] <surface>
	cmd="$workbench -cifti-smoothing \
	${datadir}/$1/MNINonLinear/Results/rfMRI_${REST}_${PHASEDIR}/rfMRI_${REST}_${PHASEDIR}_Atlas.dtseries.nii \
	4 4 COLUMN \
	${glyphsets}/$1/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.nii \
	-left-surface ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.L.very_inflated.32k_fs_LR.surf.gii \
	-right-surface ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.R.very_inflated.32k_fs_LR.surf.gii"
	echo $cmd
	$cmd

	# cifti -> metric
	cmd="$workbench -cifti-separate \
	${glyphsets}/$1/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.nii \
	COLUMN \
	-metric CORTEX_LEFT \
	${glyphsets}/$1/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric.gii"
	echo $cmd
	$cmd

	# metric -> nifti
	cmd="$workbench -metric-convert -to-nifti \
	${glyphsets}/$1/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric.gii \
	${glyphsets}/$1/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric.nii"
	echo $cmd
	$cmd

	# whatever preprocessing can be done on NIFTI timeseries files goes here:
	# bandpass filtering: values are in TRs (.6s), 166 is 0.01, 20 is 0.08:
	cmd="fslmaths \
	${glyphsets}/$1/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric.nii \
	-bptf 166 20 \
	${glyphsets}/$1/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric.nii_bptf.nii.gz"
	echo $cmd
	$cmd

	# regress out movement (6 DOF and derivatives)
	cmd="3dDetrend \
	-prefix ${glyphsets}/$1/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric.nii_bptf_res.1D  \
	-vector ${datadir}/$1/MNINonLinear/Results/rfMRI_${REST}_${PHASEDIR}/Movement_Regressors_dt.txt \
	-polort 1 \
	${glyphsets}/$1/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric.nii_bptf.nii.gz"
	echo $cmd
	$cmd

	# 3DDetrend seems to write 1D files, regardless of .nii file endings, therefore:
	cmd="3dAFNItoNIFTI \
	-prefix ${glyphsets}/$1/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric.nii_bptf_res.1D.nii
	${glyphsets}/$1/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric.nii_bptf_res.1D"
	echo $cmd
	$cmd

	# conversion back to metric
	cmd="$workbench -metric-convert -from-nifti \
	${glyphsets}/$1/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric.nii_bptf_res.1D.nii \
	${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.L.pial.32k_fs_LR.surf.gii \
	${glyphsets}/$1/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric_detrended.gii"
	echo $cmd
	$cmd

	# -> dense data series cifti
	cmd="$workbench -cifti-create-dense-timeseries \
	${glyphsets}/$1/rfMRI_${REST}_${PHASEDIR}_left_metric.dtseries.nii \
	-left-metric ${glyphsets}/$1/rfMRI_${REST}_${PHASEDIR}_Atlas_smoothed_4.dtseries.left_metric_detrended.gii"
	echo $cmd
	$cmd

	# -> correlation matrix cifti
	cmd="$workbench -cifti-correlation \
	${glyphsets}/$1/rfMRI_${REST}_${PHASEDIR}_left_metric.dtseries.nii \
	${glyphsets}/$1/rfMRI_${REST}_${PHASEDIR}_left_corr_z.nii -fisher-z"
	echo $cmd
	$cmd

	done
done

# averaging
cmd="$workbench -cifti-average \
${glyphsets}/$1/rfMRI_REST_left_corr_z.nii \
-cifti ${glyphsets}/$1/rfMRI_REST1_RL_left_corr_z.nii \
-cifti ${glyphsets}/$1/rfMRI_REST1_LR_left_corr_z.nii \
-cifti ${glyphsets}/$1/rfMRI_REST2_RL_left_corr_z.nii \
-cifti ${glyphsets}/$1/rfMRI_REST2_LR_left_corr_z.nii"
echo $cmd
$cmd

# back to r
$workbench -cifti-math 'tanh(z)' \
${glyphsets}/$1/rfMRI_REST_left_corr_avg.nii \
-var z ${glyphsets}/$1/rfMRI_REST_left_corr_z.nii


# converion to external binary gifti: header file + the binary matrix we want for braingl
cmd="$workbench -cifti-convert -to-gifti-ext \
${glyphsets}/$1/rfMRI_REST_left_corr_avg.nii \
${glyphsets}/$1/rfMRI_REST_left_corr_avg.gii"
echo $cmd
$cmd

# .glyphset file l
# TODO: remove other unneccessary large files
rm ${glyphsets}/$1/L.glyphset

echo T1w_acpc_dc_restore_brain.nii.gz >> ${glyphsets}/$1/L.glyphset
echo L.set >> ${glyphsets}/$1/L.glyphset
# TODO: ROI, shifts against anatomical?
echo rfMRI_REST_left_corr_avg.gii.data 0.5 1.0 >> ${glyphsets}/$1/L.glyphset


####################################################################################
# calculate gradients
cp ${glyphsets}/$1/rfMRI_REST_left_corr_avg.nii ${glyphsets}/$1/rfMRI_REST_left_corr_avg.dconn.nii

$workbench -cifti-gradient ${glyphsets}/$1/rfMRI_REST_left_corr_avg.dconn.nii ROW \
	${glyphsets}/$1/rfMRI_REST_left_gradient.dscalar.nii \
	-left-surface ${datadir}/${1}/MNINonLinear/fsaverage_LR32k/${1}.L.midthickness.32k_fs_LR.surf.gii \
	-average-output
	

# Export gradient results
# If this doesn't work, try using ROW instead of COLUMN
cmd="$workbench -cifti-separate ${glyphsets}/${1}/rfMRI_REST_left_gradient.dscalar.nii COLUMN \
	-metric CORTEX_LEFT ${glyphsets}/${1}/rfMRI_gradient.L.metric"
echo $cmd
$cmd

for HEMI in L; do
	cmd="$workbench -metric-convert -to-nifti \
		${glyphsets}/${1}/rfMRI_gradient.${HEMI}.metric \
		${glyphsets}/${1}/rfMRI_gradient.${HEMI}.nii"
	echo $cmd
	$cmd

	cmd="3dmaskdump -noijk ${glyphsets}/${1}/rfMRI_gradient.${HEMI}.nii \
		> ${glyphsets}/${1}/rfMRI_gradient.${HEMI}.1D"
	echo $cmd
	$cmd

	cmd="rm ${glyphsets}/${1}/rfMRI_gradient.${HEMI}.metric"
	echo $cmd
	$cmd
done

