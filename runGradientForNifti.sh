#!/bin/bash
wb=/scr/litauen1/workbench_0.82/bin_linux64/wb_command
subName=${1}
workingDir=${2}
smoothing=6

freesurferDir=/scr/kalifornien1/data/nki_enhanced/freesurfer
export SUBJECTS_DIR=${freesurferDir}

# prepare subject
subjectDir=${workingDir}/${subName}
# make dir if not there
if [ ! -d "${subjectDir}" ]
then
    mkdir -pv ${subjectDir}
    
fi

# Get the files
funcPath=/scr/melisse1/NKI_enhanced/results/${subName}/preproc/output/bandpassed/fwhm_0.0/${subName}_r00_afni_bandpassed.nii.gz
exampleFunc=/scr/melisse1/NKI_enhanced/results/${subName}/preproc/mean/afni_RfMRI_mx_645tshift.nii.gz
bbregFile=/scr/melisse1/NKI_enhanced/results/${subName}/preproc/bbreg/afni_${subName}_register.dat
cp -fv ${funcPath} ${subjectDir}/func_preproc.nii.gz
cp -fv ${exampleFunc} ${subjectDir}/exampleFunc.nii.gz
cp -fv ${bbregFile} ${subjectDir}/bbregister.dat

# align them
mri_vol2vol --mov ${subjectDir}/func_preproc.nii.gz --fstarg --o ${subjectDir}/func_preproc.aligned.nii.gz --no-resample --reg ${subjectDir}/bbregister.dat

# do the left hemisphere
mri_vol2surf \
--mov ${subjectDir}/func_preproc.aligned.nii.gz \
--reg ${subjectDir}/bbregister.dat \
--projfrac-avg 0.2 0.8 0.1 \
--trgsubject ${subName} \
--interp nearest \
--hemi lh \
--out ${subjectDir}/${subName}_rs_clean2fssurf_lh.mgh

mri_surf2surf \
--s ${subName} \
--sval ${subjectDir}/${subName}_rs_clean2fssurf_lh.mgh \
--trgsubject fsaverage5 \
--tval ${subjectDir}/${subName}_lh2fsaverage5.nii \
--hemi lh \
--cortex \
--noreshape
# --fwhm-src 6 \

# Get the curvature file into template space
mri_surf2surf \
--s ${subName} \
--sval ${freesurferDir}/${subName}/surf/lh.curv \
--trgsubject fsaverage5 \
--tval ${subjectDir}/curv_${subName}_lh2fsaverage5_${smoothing}.mgh \
--fwhm-src ${smoothing} \
--hemi lh \
--cortex \
--noreshape

# and the thickness too
mri_surf2surf \
--s ${subName} \
--sval ${freesurferDir}/${subName}/surf/lh.thickness \
--trgsubject fsaverage5 \
--tval ${subjectDir}/thickness_${subName}_lh2fsaverage5_${smoothing}.mgh \
--fwhm-src ${smoothing}
--hemi lh \
--cortex \
--noreshape

# and sulci
mri_surf2surf \
--s ${subName} \
--sval ${freesurferDir}/${subName}/surf/lh.sulc \
--trgsubject fsaverage5 \
--tval ${subjectDir}/sulc_${subName}_lh2fsaverage5_${smoothing}.mgh \
--fwhm-src ${smoothing} \
--hemi lh \
--cortex \
--noreshape

# do the right hemisphere
mri_vol2surf \
--mov ${subjectDir}/func_preproc.aligned.nii.gz \
--reg ${subjectDir}/bbregister.dat \
--projfrac-avg 0.2 0.8 0.1 \
--trgsubject ${subName} \
--interp nearest \
--hemi rh \
--out ${subjectDir}/${subName}_rs_clean2fssurf_rh.mgh

mri_surf2surf \
--s ${subName} \
--sval ${subjectDir}/${subName}_rs_clean2fssurf_rh.mgh \
--trgsubject fsaverage5 \
--tval ${subjectDir}/${subName}_rh2fsaverage5.nii \
--hemi rh \
--cortex \
--noreshape
# --fwhm-src 6 \

# Get the curvature file into template space
mri_surf2surf \
--s ${subName} \
--sval ${freesurferDir}/${subName}/surf/rh.curv \
--trgsubject fsaverage5 \
--tval ${subjectDir}/curv_${subName}_rh2fsaverage5_${smoothing}.mgh \
--fwhm-src ${smoothing} \
--hemi rh \
--cortex \
--noreshape

# and the thickness too
mri_surf2surf \
--s ${subName} \
--sval ${freesurferDir}/${subName}/surf/rh.thickness \
--trgsubject fsaverage5 \
--tval ${subjectDir}/thickness_${subName}_rh2fsaverage5_${smoothing}.mgh \
--fwhm-src ${smoothing} \
--hemi rh \
--cortex \
--noreshape

# and  sulci
mri_surf2surf \
--s ${subName} \
--sval ${freesurferDir}/${subName}/surf/rh.sulc \
--trgsubject fsaverage5 \
--tval ${subjectDir}/sulc_${subName}_rh2fsaverage5_${smoothing}.mgh \
--fwhm-src ${smoothing} \
--hemi rh \
--cortex \
--noreshape

# Get files into the correct format
# Left
mris_convert ${SUBJECTS_DIR}/fsaverage5/surf/lh.inflated ${subjectDir}/fsaverage5.lh.inflated.gii
${wb} -metric-convert -from-nifti ${subjectDir}/${subName}_lh2fsaverage5.nii ${subjectDir}/fsaverage5.lh.inflated.gii ${subjectDir}/lh_${subName}_metric.metric

# Right
mris_convert ${SUBJECTS_DIR}/fsaverage5/surf/rh.inflated ${subjectDir}/fsaverage5.rh.inflated.gii
${wb} -metric-convert -from-nifti ${subjectDir}/${subName}_rh2fsaverage5.nii ${subjectDir}/fsaverage5.rh.inflated.gii ${subjectDir}/rh_${subName}_metric.metric

# Make cifti timeseries
${wb} -cifti-create-dense-timeseries ${subjectDir}/${subName}.dtseries.nii -left-metric ${subjectDir}/lh_${subName}_metric.metric -right-metric ${subjectDir}/rh_${subName}_metric.metric -timestep 0.645

# make cifti fcon gradient
${wb} -cifti-correlation-gradient ${subjectDir}/${subName}.dtseries.nii ${subjectDir}/${subName}.gradient.dscalar.nii -left-surface ${subjectDir}/fsaverage5.lh.inflated.gii -right-surface ${subjectDir}/fsaverage5.rh.inflated.gii -surface-presmooth ${smoothing} -surface-exclude 10 -mem-limit 6

# split up cifti
${wb} -cifti-separate ${subjectDir}/${subName}.gradient.dscalar.nii COLUMN -metric CORTEX_LEFT ${subjectDir}/${subName}_rfMRI_gradient.L.metric -metric CORTEX_RIGHT ${subjectDir}/${subName}_rfMRI_gradient.R.metric

# Convert the stuff into 1D LEFT
${wb} -metric-convert -to-nifti ${subjectDir}/${subName}_rfMRI_gradient.L.metric ${subjectDir}/${subName}_rfMRI_gradient.L.nii
3dmaskdump -noijk -o ${subjectDir}/${subName}_rfMRI_gradient.L.1D ${subjectDir}/${subName}_rfMRI_gradient.L.nii
# Get rid of the metric thing
rm ${subjectDir}/${subName}_rfMRI_gradient.L.metric -rf

# Convert the stuff into 1D RIGHT
${wb} -metric-convert -to-nifti ${subjectDir}/${subName}_rfMRI_gradient.R.metric ${subjectDir}/${subName}_rfMRI_gradient.R.nii
3dmaskdump -noijk -o ${subjectDir}/${subName}_rfMRI_gradient.R.1D ${subjectDir}/${subName}_rfMRI_gradient.R.nii
# Get rid of the metric thing
rm ${subjectDir}/${subName}_rfMRI_gradient.R.metric -rf