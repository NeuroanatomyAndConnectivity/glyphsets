#!/bin/sh
#use as follows: make_glyphsets <HCP directory, e.g. 100307>
#creates: new directory with:
#copy of anatomical background nifti
#surfaces in freesurfer (pial, inflated, very inflated, spherical)
#.set files for these surfaces: l, r
#connectivity matrices for l
#.glyphset files for l

#this needs to point at the human connectome workbench commandline program
workbench=/scr/litauen1/workbench_0.82/bin_linux64/wb_command

#this needs to point at the directory where the HCP data is
datadir=/a/documents/gorgolewski

#the directory where the sets get created
glyphsets=/scr/kalifornien1/boettgerj/data/glyphsets
mkdir ${glyphsets}/$1

#copy of anatomical background
cp ${datadir}/$1/T1w/T1w_acpc_dc_restore_brain.nii.gz ${glyphsets}/$1

#surfaces in freesurfer (pial, inflated, very inflated, spherical)
#requires AFNI for the gifti_tool:
gifti_tool -infiles ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.L.pial.32k_fs_LR.surf.gii -write_asc ${glyphsets}/$1/L.pial.asc
gifti_tool -infiles ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.R.pial.32k_fs_LR.surf.gii -write_asc ${glyphsets}/$1/R.pial.asc
gifti_tool -infiles ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.L.inflated.32k_fs_LR.surf.gii -write_asc ${glyphsets}/$1/L.inflated.asc
gifti_tool -infiles ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.R.inflated.32k_fs_LR.surf.gii -write_asc ${glyphsets}/$1/R.inflated.asc
gifti_tool -infiles ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.L.very_inflated.32k_fs_LR.surf.gii -write_asc ${glyphsets}/$1/L.very_inflated.asc
gifti_tool -infiles ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.R.very_inflated.32k_fs_LR.surf.gii -write_asc ${glyphsets}/$1/R.very_inflated.asc
gifti_tool -infiles ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.L.sphere.32k_fs_LR.surf.gii -write_asc ${glyphsets}/$1/L.sphere.asc
gifti_tool -infiles ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.R.sphere.32k_fs_LR.surf.gii -write_asc ${glyphsets}/$1/R.sphere.asc

#.set files for these surfaces: l, r
#todo: offsets from the anatomical NIFTI header
#todo: loop over surface representations
rm ${glyphsets}/$1/L.set
rm ${glyphsets}/$1/R.set

echo L.pial.asc >> ${glyphsets}/$1/L.set
echo R.pial.asc >> ${glyphsets}/$1/R.set

echo L.inflated.asc >> ${glyphsets}/$1/L.set
echo R.inflated.asc >> ${glyphsets}/$1/R.set

echo L.very_inflated.asc >> ${glyphsets}/$1/L.set
echo R.very_inflated.asc >> ${glyphsets}/$1/R.set

echo L.sphere.asc >> ${glyphsets}/$1/L.set
echo R.sphere.asc >> ${glyphsets}/$1/R.set

#connectivity matrices for l

#smoothing for all four runs:
#wb_command -cifti-smoothing <cifti> <surface-kernel> <volume-kernel> <direction> <cifti-out> [-left-surface] <surface> [-right-surface] <surface>
$workbench -cifti-smoothing ${datadir}/$1/MNINonLinear/Results/rfMRI_REST1_RL/rfMRI_REST1_RL_Atlas.dtseries.nii 4 4 COLUMN ${glyphsets}/$1/rfMRI_REST1_RL_Atlas_smoothed_4.dtseries.nii -left-surface ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.L.very_inflated.32k_fs_LR.surf.gii -right-surface ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.R.very_inflated.32k_fs_LR.surf.gii
$workbench -cifti-smoothing ${datadir}/$1/MNINonLinear/Results/rfMRI_REST1_LR/rfMRI_REST1_LR_Atlas.dtseries.nii 4 4 COLUMN ${glyphsets}/$1/rfMRI_REST1_LR_Atlas_smoothed_4.dtseries.nii -left-surface ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.L.very_inflated.32k_fs_LR.surf.gii -right-surface ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.R.very_inflated.32k_fs_LR.surf.gii
$workbench -cifti-smoothing ${datadir}/$1/MNINonLinear/Results/rfMRI_REST2_RL/rfMRI_REST2_RL_Atlas.dtseries.nii 4 4 COLUMN ${glyphsets}/$1/rfMRI_REST2_RL_Atlas_smoothed_4.dtseries.nii -left-surface ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.L.very_inflated.32k_fs_LR.surf.gii -right-surface ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.R.very_inflated.32k_fs_LR.surf.gii
$workbench -cifti-smoothing ${datadir}/$1/MNINonLinear/Results/rfMRI_REST2_LR/rfMRI_REST2_LR_Atlas.dtseries.nii 4 4 COLUMN ${glyphsets}/$1/rfMRI_REST2_LR_Atlas_smoothed_4.dtseries.nii -left-surface ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.L.very_inflated.32k_fs_LR.surf.gii -right-surface ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.R.very_inflated.32k_fs_LR.surf.gii

#Run1:

#cifti -> metric -> nifti
$workbench -cifti-separate ${glyphsets}/$1/rfMRI_REST1_RL_Atlas_smoothed_4.dtseries.nii COLUMN -metric CORTEX_LEFT ${glyphsets}/$1/rfMRI_REST1_RL_Atlas_smoothed_4.dtseries.left_metric.gii
$workbench -metric-convert -to-nifti ${glyphsets}/$1/rfMRI_REST1_RL_Atlas_smoothed_4.dtseries.left_metric.gii ${glyphsets}/$1/rfMRI_REST1_RL_Atlas_smoothed_4.dtseries.left_metric.nii

#whatever preprocessing can be done on NIFTI timeseries files goes here:
#bandpass filtering: values are in TRs (.6s), 166 is 0.01, 20 is 0.08:
fslmaths ${glyphsets}/$1/rfMRI_REST1_RL_Atlas_smoothed_4.dtseries.left_metric.nii -bptf 166 20 ${glyphsets}/$1/rfMRI_REST1_RL_Atlas_smoothed_4.dtseries.left_metric.nii_bptf.nii.gz

#conversion back to metric -> dense data series cifti -> correlation matrix cifti
$workbench -metric-convert -from-nifti ${glyphsets}/$1/rfMRI_REST1_RL_Atlas_smoothed_4.dtseries.left_metric.nii_bptf.nii.gz ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.L.pial.32k_fs_LR.surf.gii ${glyphsets}/$1/rfMRI_REST1_RL_Atlas_smoothed_4.dtseries.left_metric_detrended.gii
$workbench -cifti-create-dense-timeseries ${glyphsets}/$1/rfMRI_REST1_RL_left_metric.dtseries.nii -left-metric ${glyphsets}/$1/rfMRI_REST1_RL_Atlas_smoothed_4.dtseries.left_metric_detrended.gii
$workbench -cifti-correlation ${glyphsets}/$1/rfMRI_REST1_RL_left_metric.dtseries.nii ${glyphsets}/$1/rfMRI_REST1_RL_left_corr.nii -fisher-z

#Da capo for the other three runs:
$workbench -cifti-separate ${glyphsets}/$1/rfMRI_REST1_LR_Atlas_smoothed_4.dtseries.nii COLUMN -metric CORTEX_LEFT ${glyphsets}/$1/rfMRI_REST1_LR_Atlas_smoothed_4.dtseries.left_metric.gii
$workbench -metric-convert -to-nifti ${glyphsets}/$1/rfMRI_REST1_LR_Atlas_smoothed_4.dtseries.left_metric.gii ${glyphsets}/$1/rfMRI_REST1_LR_Atlas_smoothed_4.dtseries.left_metric.nii
fslmaths ${glyphsets}/$1/rfMRI_REST1_LR_Atlas_smoothed_4.dtseries.left_metric.nii -bptf 166 20 ${glyphsets}/$1/rfMRI_REST1_LR_Atlas_smoothed_4.dtseries.left_metric.nii_bptf.nii.gz
$workbench -metric-convert -from-nifti ${glyphsets}/$1/rfMRI_REST1_LR_Atlas_smoothed_4.dtseries.left_metric.nii_bptf.nii.gz ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.L.pial.32k_fs_LR.surf.gii ${glyphsets}/$1/rfMRI_REST1_LR_Atlas_smoothed_4.dtseries.left_metric_detrended.gii
$workbench -cifti-create-dense-timeseries ${glyphsets}/$1/rfMRI_REST1_LR_left_metric.dtseries.nii -left-metric ${glyphsets}/$1/rfMRI_REST1_LR_Atlas_smoothed_4.dtseries.left_metric_detrended.gii
$workbench -cifti-correlation ${glyphsets}/$1/rfMRI_REST1_LR_left_metric.dtseries.nii ${glyphsets}/$1/rfMRI_REST1_LR_left_corr.nii -fisher-z

$workbench -cifti-separate ${glyphsets}/$1/rfMRI_REST2_RL_Atlas_smoothed_4.dtseries.nii COLUMN -metric CORTEX_LEFT ${glyphsets}/$1/rfMRI_REST2_RL_Atlas_smoothed_4.dtseries.left_metric.gii
$workbench -metric-convert -to-nifti ${glyphsets}/$1/rfMRI_REST2_RL_Atlas_smoothed_4.dtseries.left_metric.gii ${glyphsets}/$1/rfMRI_REST2_RL_Atlas_smoothed_4.dtseries.left_metric.nii
fslmaths ${glyphsets}/$1/rfMRI_REST2_RL_Atlas_smoothed_4.dtseries.left_metric.nii -bptf 166 20 ${glyphsets}/$1/rfMRI_REST2_RL_Atlas_smoothed_4.dtseries.left_metric.nii_bptf.nii.gz
$workbench -metric-convert -from-nifti ${glyphsets}/$1/rfMRI_REST2_RL_Atlas_smoothed_4.dtseries.left_metric.nii_bptf.nii.gz ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.L.pial.32k_fs_LR.surf.gii ${glyphsets}/$1/rfMRI_REST2_RL_Atlas_smoothed_4.dtseries.left_metric_detrended.gii
$workbench -cifti-create-dense-timeseries ${glyphsets}/$1/rfMRI_REST2_RL_left_metric.dtseries.nii -left-metric ${glyphsets}/$1/rfMRI_REST2_RL_Atlas_smoothed_4.dtseries.left_metric_detrended.gii
$workbench -cifti-correlation ${glyphsets}/$1/rfMRI_REST2_RL_left_metric.dtseries.nii ${glyphsets}/$1/rfMRI_REST2_RL_left_corr.nii -fisher-z

$workbench -cifti-separate ${glyphsets}/$1/rfMRI_REST2_LR_Atlas_smoothed_4.dtseries.nii COLUMN -metric CORTEX_LEFT ${glyphsets}/$1/rfMRI_REST2_LR_Atlas_smoothed_4.dtseries.left_metric.gii
$workbench -metric-convert -to-nifti ${glyphsets}/$1/rfMRI_REST2_LR_Atlas_smoothed_4.dtseries.left_metric.gii ${glyphsets}/$1/rfMRI_REST2_LR_Atlas_smoothed_4.dtseries.left_metric.nii
fslmaths ${glyphsets}/$1/rfMRI_REST2_LR_Atlas_smoothed_4.dtseries.left_metric.nii -bptf 166 20 ${glyphsets}/$1/rfMRI_REST2_LR_Atlas_smoothed_4.dtseries.left_metric.nii_bptf.nii.gz
$workbench -metric-convert -from-nifti ${glyphsets}/$1/rfMRI_REST2_LR_Atlas_smoothed_4.dtseries.left_metric.nii_bptf.nii.gz ${datadir}/$1/MNINonLinear/fsaverage_LR32k/$1.L.pial.32k_fs_LR.surf.gii ${glyphsets}/$1/rfMRI_REST2_LR_Atlas_smoothed_4.dtseries.left_metric_detrended.gii
$workbench -cifti-create-dense-timeseries ${glyphsets}/$1/rfMRI_REST2_LR_left_metric.dtseries.nii -left-metric ${glyphsets}/$1/rfMRI_REST2_LR_Atlas_smoothed_4.dtseries.left_metric_detrended.gii
$workbench -cifti-correlation ${glyphsets}/$1/rfMRI_REST2_LR_left_metric.dtseries.nii ${glyphsets}/$1/rfMRI_REST2_LR_left_corr.nii -fisher-z

#averaging
$workbench -cifti-average ${glyphsets}/$1/rfMRI_REST_left_corr.nii -cifti ${glyphsets}/$1/rfMRI_REST1_RL_left_corr.nii -cifti ${glyphsets}/$1/rfMRI_REST1_LR_left_corr.nii -cifti ${glyphsets}/$1/rfMRI_REST2_RL_left_corr.nii -cifti ${glyphsets}/$1/rfMRI_REST2_LR_left_corr.nii

#back to r
$workbench -cifti-math 'tanh(z)' ${glyphsets}/$1/rfMRI_REST_left_corr_avg.nii -var z ${glyphsets}/$1/rfMRI_REST_left_corr.nii

#converion to external binary gifti: header file + the binary matrix we want for braingl
$workbench -cifti-convert -to-gifti-ext ${glyphsets}/$1/rfMRI_REST_left_corr_avg.nii ${glyphsets}/$1/rfMRI_REST_left_corr_avg.gii

#.glyphset file l
rm ${glyphsets}/$1/L.glyphset

echo T1w_acpc_dc_restore_brain.nii.gz >> ${glyphsets}/$1/L.glyphset
echo L.set >> ${glyphsets}/$1/L.glyphset
#Todo: ROI, shift against anatomical
echo rfMRI_REST_left_corr_avg.gii.data 0.5 1.0 >> ${glyphsets}/$1/L.glyphset

