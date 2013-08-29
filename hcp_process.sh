#!/bin/bash

usage="
$(basename "$0") -- a script for processing HCP (and HCP-like) data

where:
	-h	show this help text
	-k	specific location of wb_command [default: /scr/liberia1/connectome_wb/workbench/bin_linux64/wb_command]
	-d	directory for hcp data [default: /a/documents/connectome/]
	-w	working directory for outputting results [default: /scr/kansas1/margulies/hcp]
	-r	hcp release [example: q1 or q2]
	-p	preprocess data
	-g	output glyphsets for use in braingl
	-t	output transition maps [options: averageCorr, averageTrans]
	-T	output transition map of transition maps
	-K	process transition for NKI_Enhanced data
	-c	output connectivity matrices	
	-x	remove all files expect specified final outputs
	-s 	subject name
	"
if [ -z "$1" ]; then 
    echo "${usage}"
    exit
fi

# Defaults:
workbench="/scr/liberia1/connectome_wb/workbench/bin_linux64/wb_command"
dir="/a/documents/connectome/"
workingDir="/scr/kansas1/margulies/hcp/"

### TO DO: Insert following variables into options above
ss=4 	# surface-presmooth 
vs=4 	# volume-presmooth
se=10 	# surface-exclude 
ve=10   # volume-exclude
ml=40 	# mem-limit

while getopts ':hkdwrpcgtTcxs:' option; do
  case "$option" in
    h) 	echo "$usage"
       	exit
       	;;
		k) workbench=$OPTARG
    d) 	dir=$OPTARG
       	;;
		w) 	workingDir=$OPTARG
				;;
		r)	datadir=${dir}/$OPTARG
		p)	echo "Preprocessing"
				preprocessing
		c) 	echo "Creating connectivity matrix"
				connectivity
		g)	echo "Creating glyphsets"
				glyphsets
		t)	echo "Creating transition maps"
				trans_order=$OPTARG
				transition
		T)	echo "Creating second transition maps"
				transition_second
		K)	echo "Creating transition maps for NKI_Enhanced data"
						transition_nki
		x)	echo "removing unnecessary files"
				cleanup
		s)	echo "processing subject: $OPTARG"
				sub=$OPTARG
    :) 	printf "missing argument for -%s\n" "$OPTARG" >&2
       	echo "$usage" >&2
       	exit 1
       	;;
   \?) 	printf "illegal option: -%s\n" "$OPTARG" >&2
       	echo "$usage" >&2
       	exit 1
       	;;
	esac
done
shift $((OPTIND - 1))

## the directory where the sets get created
if [ ! -d ${workingDir}/${sub} ]; then
	mkdir ${workingDir}/${sub}
fi
#########################################################
#################### BEGIN FUNCTIONS ####################
#########################################################

#########################################################
#################### PREPROCESSING ######################
#########################################################
preprocessing(){
	for REST in REST1 REST2; do
		for PHASE in RL LR; do
			for HEMI in LEFT RIGHT; do
				## Preprocessing:
				# cifti -> metric
				if [ ! -f ${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.gii ]; then 
				cmd="$workbench -cifti-separate \
					${datadir}/${sub}/MNINonLinear/Results/rfMRI_${REST}_${PHASE}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.nii \
					COLUMN \
					-metric CORTEX_${HEMI} \
					${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.gii"
				echo $cmd; $cmd; fi
				# metric -> nifti
				if [ ! -f ${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.nii ]; then 
				cmd="$workbench -metric-convert -to-nifti \
					${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.gii \
					${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.nii"
				echo $cmd; $cmd; fi
				# regress out movement and bandpass filter
				if [ ! -f ${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.preproc.nii ]; then 
				cp ${datadir}/${sub}/MNINonLinear/Results/rfMRI_${REST}_${PHASE}/Movement_Regressors.txt \
					${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_Movement_Regressors.1D
				cp ${datadir}/${sub}/MNINonLinear/Results/rfMRI_${REST}_${PHASE}/Movement_Regressors_dt.txt \
					${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_Movement_Regressors_dt.1D
				cmd="3dBandpass -ort ${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_Movement_Regressors.1D \
					-ort ${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_Movement_Regressors.1D \
					-prefix ${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.preproc.1D \
					-dt 0.720 -band 0.01 0.1 \
					${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.nii"
				echo $cmd; $cmd
				cmd="3dAFNItoNIFTI -prefix ${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.preproc.nii \
					${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.preproc.1D"
				echo $cmd; $cmd; fi

				if [ ${HEMI}="LEFT" ]; then
					surfHEMI="L"
				elif [ ${HEMI}="RIGHT" ]; then
					surfHEMI="R" 
				fi
				# conversion back to metric
				if [ ! -f ${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.preproc.gii ]; then 
				cmd="$workbench -metric-convert -from-nifti \
					${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.preproc.nii \
					${datadir}/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.${surfHEMI}.pial.32k_fs_LR.surf.gii \
					${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.${HEMI}.metric.preproc.gii"
				echo $cmd; $cmd; fi
			done

			# -> dense data series cifti
			if [ ! -f ${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_preproc.dtseries.nii ]; then
			cmd="$workbench -cifti-create-dense-timeseries \
				${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_preproc.dtseries.nii \
				-left-metric ${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.LEFT.metric.preproc.gii \
				-right-metric ${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_Atlas.dtseries.RIGHT.metric.preproc.gii"
			echo $cmd; $cmd; fi
			
			# Spatial smoothing at 4mm/2.355 = sigma
			if [ ! -f ${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_preproc.ss.dtseries.nii ]; then
			sigmaSurf=1.699 #$((${ss}/2.3548))
			sigmaVol=1.699 #$((${vs}/2.3548))
			cmd="$workbench -cifti-smoothing ${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_preproc.dtseries.nii \
				${sigmaSurf} ${sigmaVol} COLUMN \
				${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_preproc.ss.dtseries.nii
				-left-surface ${datadir}/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.L.pial.32k_fs_LR.surf.gii \
				-right-surface ${datadir}/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.R.pial.32k_fs_LR.surf.gii \
				-fix-zeros-surface"
				#-fix-zeros-volume \
			echo $cmd; $cmd; fi
		done
	done
}

#########################################################
#################### CONNECTIVITY #######################
#########################################################
connectivity(){
	for REST in REST1 REST2; do
		for PHASE in RL LR; do
			if [ ! -f ${workingDir}/${sub}/rfMRI_REST.dconn.nii ]; then
			if [ ! -f ${workingDir}/${sub}/rfMRI_${REST}_${PHASE}.dconn.nii ]; then 
			cmd="$workbench -cifti-correlation \
				${workingDir}/${sub}/rfMRI_${REST}_${PHASE}_preproc.ss.dtseries.nii \
				${workingDir}/${sub}/rfMRI_${REST}_${PHASE}.z.dconn.nii \
				-fisher-z \
				-mem-limit ${ml}"
				#-roi-override
				#-left-roi ${datadir}/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.L.atlasroi.32k_fs_LR.shape.gii \
				#-right-roi ${datadir}/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.R.atlasroi.32k_fs_LR.shape.gii \
		
			echo $cmd; $cmd; fi; fi
		done
	done
	
	## Averaging across four runs
	if [ ! -f ${workingDir}/${sub}/rfMRI_REST.dconn.nii ]; then
	if [ ! -f ${workingDir}/${sub}/rfMRI_REST_z_dconn.nii ]; then 
	cmd="$workbench -cifti-average ${workingDir}/${sub}/rfMRI_REST_z.dconn.nii \
		-cifti ${workingDir}/${sub}/rfMRI_REST1_RL.z.dconn.nii \
		-cifti ${workingDir}/${sub}/rfMRI_REST1_LR.z.dconn.nii \
		-cifti ${workingDir}/${sub}/rfMRI_REST2_RL.z.dconn.nii \
		-cifti ${workingDir}/${sub}/rfMRI_REST2_LR.z.dconn.nii"
	echo $cmd; $cmd; fi; fi

	## Transform z-to-r
	if [ ! -f ${workingDir}/${sub}/rfMRI_REST.dconn.nii ]; then 
	$workbench -cifti-math 'tanh(z)' ${workingDir}/${sub}/rfMRI_REST.dconn.nii \
		-fixnan 0 -var z ${workingDir}/${sub}/rfMRI_REST_z.dconn.nii 
	fi
	
}

#########################################################
#################### GLYPHSETS ##########################
#########################################################
glyphsets(){
	## surfaces in freesurfer
	## requires AFNI for the gifti_tool: 
	for HEMI in R L; do
		for SURF in pial inflated sphere midthickness; do
			if [ ! -f ${workingDir}/${sub}/${HEMI}.${SURF}.asc ]; then
			cmd="gifti_tool -infiles ${datadir}/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.${HEMI}.${SURF}.32k_fs_LR.surf.gii -write_asc ${workingDir}/${sub}/${HEMI}.${SURF}.asc"
			echo $cmd; $cmd; fi
		done
		for SHAPE in sulc curvature corrThickness thickness; do
			if [ ! -f ${workingDir}/${sub}/${HEMI}.${SHAPE}.shape.1D ]; then 
			cmd="gifti_tool -infiles \
				${datadir}/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.${HEMI}.${SHAPE}.32k_fs_LR.shape.gii  \
				-write_1D ${workingDir}/${sub}/${HEMI}.${SHAPE}.shape.1D"
			echo $cmd; $cmd; fi
		done
	done 
	
	preprocess
	
	correlation
}

#########################################################
#################### TRANSITION #########################
#########################################################
transition(){
	
	preprocess
	
	if [ trans_order="averageConn"; then
		## Calculate gradient
		if [ ! -f ${workingDir}/${sub}/rfMRI_gradient.dscalar.nii ]; then 
		connectivity
		
		cmd="$workbench -cifti-gradient ${workingDir}/${sub}/rfMRI_REST.dconn.nii ROW ${workingDir}/${sub}/rfMRI_gradient.dscalar.nii \
			-left-surface ${datadir}/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.L.midthickness.32k_fs_LR.surf.gii \
			-right-surface ${datadir}/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.R.midthickness.32k_fs_LR.surf.gii \
			-surface-presmooth ${ss} \
			-volume-presmooth ${vs} \
			-average-output"
		echo $cmd; $cmd; fi

		# Export gradient results
		if [ ! -f ${workingDir}/${sub}/rfMRI_gradient.R.dconn.nii ]; then 
		cmd="$workbench -cifti-separate ${workingDir}/${sub}/rfMRI_gradient.dscalar.nii COLUMN \
			-metric CORTEX_LEFT ${workingDir}/${sub}/rfMRI_gradient.L.metric \
			-metric CORTEX_RIGHT ${workingDir}/${sub}/rfMRI_gradient.R.metric"
		echo $cmd; $cmd; fi
		fi
	fi
	
	if [ trans_order="averageTrans"]; then
		## Create connectivity matrices
		for REST in REST1 REST2; do
			for PHASEDIR in RL LR; do
			## Calculate gradient
			cmd="$workbench -cifti-correlation-gradient \
				${datadir}/${sub}/MNINonLinear/Results/rfMRI_${REST}_${PHASEDIR}/rfMRI_${REST}_${PHASEDIR}_Atlas.dtseries.nii \
				${workingDir}/${sub}/rfMRI_${REST}_${PHASEDIR}_gradient.dscalar.nii \
				-left-surface ${datadir}/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.L.midthickness.32k_fs_LR.surf.gii \
				-right-surface ${datadir}/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.R.midthickness.32k_fs_LR.surf.gii \
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
		cmd="$workbench -cifti-average ${workingDir}/${sub}/rfMRI_gradient.dscalar.nii \
			-cifti ${workingDir}/${sub}/rfMRI_REST1_RL_gradient.dscalar.nii \
			-cifti ${workingDir}/${sub}/rfMRI_REST1_LR_gradient.dscalar.nii \
			-cifti ${workingDir}/${sub}/rfMRI_REST2_RL_gradient.dscalar.nii \
			-cifti ${workingDir}/${sub}/rfMRI_REST2_LR_gradient.dscalar.nii"
		echo $cmd
		$cmd
	fi
}

#########################################################
#################### TRANSITION SECOND ##################
#########################################################
transition_second(){
	for HEMI in L R; do
		if [ ! -f ${workingDir}/${sub}/rfMRI_gradient.${HEMI}.nii ]; then 
		cmd="$workbench -metric-convert -to-nifti \
			${workingDir}/${sub}/rfMRI_gradient.${HEMI}.metric \
			${workingDir}/${sub}/rfMRI_gradient.${HEMI}.nii"
		echo $cmd; $cmd; fi
		if [ ! -f ${workingDir}/${sub}/rfMRI_gradient.${HEMI}.1D ]; then 
		3dmaskdump -noijk ${workingDir}/${sub}/rfMRI_gradient.${HEMI}.nii >${workingDir}/${sub}/rfMRI_gradient.${HEMI}.1D
		cmd="rm ${workingDir}/${sub}/rfMRI_gradient.${HEMI}.metric"
		echo $cmd; $cmd; fi
	done

	## Calculate gradient of gradient
	if [ ! -f ${workingDir}/${sub}/rfMRI_gradient2.dscalar.nii ]; then
	cmd="$workbench -cifti-gradient ${workingDir}/${sub}/rfMRI_gradient.dscalar.nii COLUMN ${workingDir}/${sub}/rfMRI_gradient2.dscalar.nii\
		-left-surface ${datadir}/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.L.midthickness.32k_fs_LR.surf.gii \
		-right-surface ${datadir}/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.R.midthickness.32k_fs_LR.surf.gii \
		-surface-presmooth ${ss}"
	echo $cmd; $cmd; fi

	# Export gradient-of-gradient results
	if [ ! -f ${workingDir}/${sub}/rfMRI_gradient2.L.dconn.nii ]; then 
	cmd="$workbench -cifti-separate ${workingDir}/${sub}/rfMRI_gradient2.dscalar.nii COLUMN \
		-metric CORTEX_LEFT ${workingDir}/${sub}/rfMRI_gradient2.L.metric \
		-metric CORTEX_RIGHT ${workingDir}/${sub}/rfMRI_gradient2.R.metric"
	echo $cmd; $cmd; fi

	for HEMI in L R; do
		if [ ! -f ${workingDir}/${sub}/rfMRI_gradient2.${HEMI}.nii ]; then 
		cmd="$workbench -metric-convert -to-nifti \
			${workingDir}/${sub}/rfMRI_gradient2.${HEMI}.metric \
			${workingDir}/${sub}/rfMRI_gradient2.${HEMI}.nii"
		echo $cmd; $cmd; fi
		if [ ! -f ${workingDir}/${sub}/rfMRI_gradient2.${HEMI}.1D ]; then 
		3dmaskdump -noijk ${workingDir}/${sub}/rfMRI_gradient2.${HEMI}.nii >${workingDir}/${sub}/rfMRI_gradient2.${HEMI}.1D
		cmd="rm ${workingDir}/${sub}/rfMRI_gradient2.${HEMI}.metric"
		echo $cmd; $cmd; fi
	done
}

#########################################################
#################### TRANSITION NKI #####################
#########################################################
transition_nki(){
	smoothing=6
	freesurferDir=/scr/kalifornien1/data/nki_enhanced/freesurfer
	export SUBJECTS_DIR=${freesurferDir}

	# prepare subject
	subjectDir=${workingDir}/${sub}
	# make dir if not there
	if [ ! -d "${subjectDir}" ]
	then
	    mkdir -pv ${subjectDir}
	fi

	# Get the files
	funcPath=/scr/melisse1/NKI_enhanced/results/${sub}/preproc/output/bandpassed/fwhm_0.0/${sub}_r00_afni_bandpassed.nii.gz
	exampleFunc=/scr/melisse1/NKI_enhanced/results/${sub}/preproc/mean/afni_RfMRI_mx_645tshift.nii.gz
	bbregFile=/scr/melisse1/NKI_enhanced/results/${sub}/preproc/bbreg/afni_${sub}_register.dat
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
	--trgsubject ${sub} \
	--interp nearest \
	--hemi lh \
	--out ${subjectDir}/${sub}_rs_clean2fssurf_lh.mgh

	mri_surf2surf \
	--s ${sub} \
	--sval ${subjectDir}/${sub}_rs_clean2fssurf_lh.mgh \
	--trgsubject fsaverage5 \
	--tval ${subjectDir}/${sub}_lh2fsaverage5.nii \
	--hemi lh \
	--cortex \
	--noreshape
	# --fwhm-src 6 \

	# Get the curvature file into template space
	mri_surf2surf \
	--s ${sub} \
	--sval ${freesurferDir}/${sub}/surf/lh.curv \
	--trgsubject fsaverage5 \
	--tval ${subjectDir}/curv_${sub}_lh2fsaverage5_${smoothing}.mgh \
	--fwhm-src ${smoothing} \
	--hemi lh \
	--cortex \
	--noreshape

	# and the thickness too
	mri_surf2surf \
	--s ${sub} \
	--sval ${freesurferDir}/${sub}/surf/lh.thickness \
	--trgsubject fsaverage5 \
	--tval ${subjectDir}/thickness_${sub}_lh2fsaverage5_${smoothing}.mgh \
	--fwhm-src ${smoothing}
	--hemi lh \
	--cortex \
	--noreshape

	# and sulci
	mri_surf2surf \
	--s ${sub} \
	--sval ${freesurferDir}/${sub}/surf/lh.sulc \
	--trgsubject fsaverage5 \
	--tval ${subjectDir}/sulc_${sub}_lh2fsaverage5_${smoothing}.mgh \
	--fwhm-src ${smoothing} \
	--hemi lh \
	--cortex \
	--noreshape

	# do the right hemisphere
	mri_vol2surf \
	--mov ${subjectDir}/func_preproc.aligned.nii.gz \
	--reg ${subjectDir}/bbregister.dat \
	--projfrac-avg 0.2 0.8 0.1 \
	--trgsubject ${sub} \
	--interp nearest \
	--hemi rh \
	--out ${subjectDir}/${sub}_rs_clean2fssurf_rh.mgh

	mri_surf2surf \
	--s ${sub} \
	--sval ${subjectDir}/${sub}_rs_clean2fssurf_rh.mgh \
	--trgsubject fsaverage5 \
	--tval ${subjectDir}/${sub}_rh2fsaverage5.nii \
	--hemi rh \
	--cortex \
	--noreshape
	# --fwhm-src 6 \

	# Get the curvature file into template space
	mri_surf2surf \
	--s ${sub} \
	--sval ${freesurferDir}/${sub}/surf/rh.curv \
	--trgsubject fsaverage5 \
	--tval ${subjectDir}/curv_${sub}_rh2fsaverage5_${smoothing}.mgh \
	--fwhm-src ${smoothing} \
	--hemi rh \
	--cortex \
	--noreshape

	# and the thickness too
	mri_surf2surf \
	--s ${sub} \
	--sval ${freesurferDir}/${sub}/surf/rh.thickness \
	--trgsubject fsaverage5 \
	--tval ${subjectDir}/thickness_${sub}_rh2fsaverage5_${smoothing}.mgh \
	--fwhm-src ${smoothing} \
	--hemi rh \
	--cortex \
	--noreshape

	# and  sulci
	mri_surf2surf \
	--s ${sub} \
	--sval ${freesurferDir}/${sub}/surf/rh.sulc \
	--trgsubject fsaverage5 \
	--tval ${subjectDir}/sulc_${sub}_rh2fsaverage5_${smoothing}.mgh \
	--fwhm-src ${smoothing} \
	--hemi rh \
	--cortex \
	--noreshape

	# Get files into the correct format
	# Left
	mris_convert ${SUBJECTS_DIR}/fsaverage5/surf/lh.inflated ${subjectDir}/fsaverage5.lh.inflated.gii
	${wb} -metric-convert -from-nifti ${subjectDir}/${sub}_lh2fsaverage5.nii ${subjectDir}/fsaverage5.lh.inflated.gii ${subjectDir}/lh_${sub}_metric.metric

	# Right
	mris_convert ${SUBJECTS_DIR}/fsaverage5/surf/rh.inflated ${subjectDir}/fsaverage5.rh.inflated.gii
	${wb} -metric-convert -from-nifti ${subjectDir}/${sub}_rh2fsaverage5.nii ${subjectDir}/fsaverage5.rh.inflated.gii ${subjectDir}/rh_${sub}_metric.metric

	# Make cifti timeseries
	${wb} -cifti-create-dense-timeseries ${subjectDir}/${sub}.dtseries.nii -left-metric ${subjectDir}/lh_${sub}_metric.metric -right-metric ${subjectDir}/rh_${sub}_metric.metric -timestep 0.645

	# make cifti fcon gradient
	${wb} -cifti-correlation-gradient ${subjectDir}/${sub}.dtseries.nii ${subjectDir}/${sub}.gradient.dscalar.nii -left-surface ${subjectDir}/fsaverage5.lh.inflated.gii -right-surface ${subjectDir}/fsaverage5.rh.inflated.gii -surface-presmooth ${smoothing} -surface-exclude 10 -mem-limit 6

	# split up cifti
	${wb} -cifti-separate ${subjectDir}/${sub}.gradient.dscalar.nii COLUMN -metric CORTEX_LEFT ${subjectDir}/${sub}_rfMRI_gradient.L.metric -metric CORTEX_RIGHT ${subjectDir}/${sub}_rfMRI_gradient.R.metric

	# Convert the stuff into 1D LEFT
	${wb} -metric-convert -to-nifti ${subjectDir}/${sub}_rfMRI_gradient.L.metric ${subjectDir}/${sub}_rfMRI_gradient.L.nii
	3dmaskdump -noijk -o ${subjectDir}/${sub}_rfMRI_gradient.L.1D ${subjectDir}/${sub}_rfMRI_gradient.L.nii
	# Get rid of the metric thing
	rm ${subjectDir}/${sub}_rfMRI_gradient.L.metric -rf

	# Convert the stuff into 1D RIGHT
	${wb} -metric-convert -to-nifti ${subjectDir}/${sub}_rfMRI_gradient.R.metric ${subjectDir}/${sub}_rfMRI_gradient.R.nii
	3dmaskdump -noijk -o ${subjectDir}/${sub}_rfMRI_gradient.R.1D ${subjectDir}/${sub}_rfMRI_gradient.R.nii
	# Get rid of the metric thing
	rm ${subjectDir}/${sub}_rfMRI_gradient.R.metric -rf
}

#########################################################
#################### CLEANUP ############################
#########################################################
cleanup(){
	## Clean up unnecessary files:
	if [ -f ${workingDir}/${sub}/rfMRI_REST.dconn.nii ]; then
	cmd="rm -f ${workingDir}/${sub}/rfMRI_REST_z.dconn.nii \
		${workingDir}/${sub}/rfMRI_REST?_??.dconn.nii \
		${workingDir}/${sub}/rfMRI_REST?_??_Atlas.dtseries.*.metric.*"
	echo $cmd; $cmd; fi
	#if [ -f ${workingDir}/${sub}/rfMRI_gradient.dscalar.nii ]; then
	#cmd="rm -f ${workingDir}/${sub}/rfMRI_REST.dconn.nii"
	#echo $cmd; $cmd; fi
}