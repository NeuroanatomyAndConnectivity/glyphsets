#!/bin/sh
# script for processing HCP Q3 fMRI FIX-denoised data for use in brainGL
# use as follows: make_glyphsets_HCP_Q3.sh <HCP directory, e.g. 100307> <data directory> <output directory>
# creates a new directory with:
# copy of anatomical background nifti
# surfaces in freesurfer format
# .set files for these surfaces: l, r
# connectivity matrices for l
# .glyphset files for l

# this needs to point at the human connectome workbench commandline program
workbench=/scr/murg1/workbench/bin_linux64/wb_command

#subject identifier
subName=${1}

# this needs to point at the directory where the HCP data is
datadir=${2}

# the directory where the sets get created
glyphsets=${3}
mkdir ${glyphsets}/${subName}

# copy of anatomical background
cp ${datadir}/${subName}/T1w/T1w_acpc_dc_restore_brain.nii.gz ${glyphsets}/${subName}

# convert surfaces to freesurfer (requires AFNI for the gifti_tool)
# create .set files for these surfaces
# write coordinate offsets from the anatomical NIFTI header
for HEMI in R L; do
	rm ${glyphsets}/${subName}/${HEMI}.set
	for SURF in pial inflated very_inflated sphere midthickness; do
		gifti_tool -infiles ${datadir}/${subName}/MNINonLinear/fsaverage_LR32k/${subName}.${HEMI}.${SURF}.32k_fs_LR.surf.gii -write_asc ${glyphsets}/${subName}/${HEMI}.${SURF}.asc
		echo ${HEMI}.${SURF}.asc 91.3 126.0 72.0 >> ${glyphsets}/${subName}/${HEMI}.set
	done
done

# connectivity matrices

# for all four runs

for REST in REST1 REST2; do
	for PHASEDIR in RL LR; do

	# cifti -> metric
	#LEFT
	cmd="$workbench -cifti-separate \
	${datadir}/${subName}/MNINonLinear/Results/rfMRI_${REST}_${PHASEDIR}/rfMRI_${REST}_${PHASEDIR}_Atlas_hp2000_clean.dtseries.nii \
	COLUMN \
	-metric CORTEX_LEFT \
	${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_Atlas_hp2000_clean.dtseries.left_metric.gii"
	echo $cmd
	$cmd

	#RIGHT
	cmd="$workbench -cifti-separate \
	${datadir}/${subName}/MNINonLinear/Results/rfMRI_${REST}_${PHASEDIR}/rfMRI_${REST}_${PHASEDIR}_Atlas_hp2000_clean.dtseries.nii \
	COLUMN \
	-metric CORTEX_RIGHT \
	${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_Atlas_hp2000_clean.dtseries.right_metric.gii"
	echo $cmd
	$cmd

		for HEMI in left right; do
	
		# -> dense data series cifti
		cmd="$workbench -cifti-create-dense-timeseries \
		${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_${HEMI}.dtseries.nii \
		-${HEMI}-metric ${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_Atlas_hp2000_clean.dtseries.${HEMI}_metric.gii"
		echo $cmd
		$cmd

		# smoothing 
		#wb_command -cifti-smoothing <cifti> <surface-kernel> <volume-kernel> <direction> <cifti-out> [-left-surface] <surface> [-right-surface] <surface>
		cmd="$workbench -cifti-smoothing \
		${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_${HEMI}.dtseries.nii \
		2 2 COLUMN \
		${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_${HEMI}_smoothed.dtseries.nii \
		-${HEMI}-surface ${datadir}/${subName}/MNINonLinear/fsaverage_LR32k/${subName}.L.very_inflated.32k_fs_LR.surf.gii"
		echo $cmd
		$cmd

		# -> correlation matrix cifti
		cmd="$workbench -cifti-correlation \
		${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_${HEMI}_smoothed.dtseries.nii \
		${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_${HEMI}_corr.nii -fisher-z"
		echo $cmd
		$cmd

		done
	done
done

for HEMI in left right; do
# averaging
cmd="$workbench -cifti-average \
${glyphsets}/${subName}/rfMRI_REST_${HEMI}_corr.nii \
-cifti ${glyphsets}/${subName}/rfMRI_REST1_RL_${HEMI}_corr.nii \
-cifti ${glyphsets}/${subName}/rfMRI_REST1_LR_${HEMI}_corr.nii \
-cifti ${glyphsets}/${subName}/rfMRI_REST2_RL_${HEMI}_corr.nii \
-cifti ${glyphsets}/${subName}/rfMRI_REST2_LR_${HEMI}_corr.nii"
echo $cmd
$cmd

# back to r
$workbench -cifti-math 'tanh(z)' \
${glyphsets}/${subName}/rfMRI_REST_${HEMI}_corr_avg.nii \
-var z ${glyphsets}/${subName}/rfMRI_REST_${HEMI}_corr.nii

# converion to external binary gifti: header file + the binary matrix we want for braingl
cmd="$workbench -cifti-convert -to-gifti-ext \
${glyphsets}/${subName}/rfMRI_REST_${HEMI}_corr_avg.nii \
${glyphsets}/${subName}/rfMRI_REST_${HEMI}_corr_avg.gii"
echo $cmd
$cmd
done


# .glyphset files
rm ${glyphsets}/${subName}/L.glyphset
echo T1w_acpc_dc_restore_brain.nii.gz >> ${glyphsets}/${subName}/L.glyphset
echo L.set >> ${glyphsets}/${subName}/L.glyphset
echo rfMRI_REST_left_corr_avg.gii.data -1.0 1.0 >> ${glyphsets}/${subName}/L.glyphset

rm ${glyphsets}/${subName}/R.glyphset
echo T1w_acpc_dc_restore_brain.nii.gz >> ${glyphsets}/${subName}/R.glyphset
echo R.set >> ${glyphsets}/${subName}/R.glyphset
echo rfMRI_REST_right_corr_avg.gii.data -1.0 1.0 >> ${glyphsets}/${subName}/R.glyphset

# remove unneccessary files
for REST in REST1 REST2; do
	for PHASEDIR in RL LR; do
		for HEMI in left right; do

		rm ${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_${HEMI}_corr.nii
		rm ${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_${HEMI}.dtseries.nii
		rm ${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_Atlas_hp2000_clean.dtseries.${HEMI}_metric.gii

		rm ${glyphsets}/${subName}/rfMRI_REST_${HEMI}_corr.nii
		rm ${glyphsets}/${subName}/rfMRI_REST_${HEMI}_corr_avg.nii
		rm ${glyphsets}/${subName}/rfMRI_REST_${HEMI}_corr_avg.gii
		
		done
	done
done


