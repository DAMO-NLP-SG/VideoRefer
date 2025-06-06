
EVAL_DATA_DIR=./eval
OUTPUT_DIR=eval_output
CKPT='./checkpoints/VideoRefer-7b'

gpu_list="${CUDA_VISIBLE_DEVICES:-0}"
IFS=',' read -ra GPULIST <<< "$gpu_list"

# divide data via the number of GPUs per task
GPUS_PER_TASK=1
CHUNKS=$((${#GPULIST[@]}/$GPUS_PER_TASK))

output_file=${OUTPUT_DIR}/videorefer-bench-q/answers/${CKPT_NAME}/merge.json

# judge if the number of json lines is 0
if [ ! -f "$output_file" ] || [ $(cat "$output_file" | wc -l) -eq 0 ]; then
    rm -f ${OUTPUT_DIR}/videorefer-bench-q/answers/${CKPT_NAME}/*.json
fi

if [ ! -f "$output_file" ]; then
    for IDX in $(seq 0 $((CHUNKS-1))); do
        gpu_devices=$(IFS=,; echo "${GPULIST[*]:$(($IDX*$GPUS_PER_TASK)):$GPUS_PER_TASK}")
        TRANSFORMERS_OFFLINE=1 CUDA_VISIBLE_DEVICES=${gpu_devices} python3 videorefer/eval/inference_videorefer_q_bench.py \
            --model-path ${CKPT} \
            --video-folder ${EVAL_DATA_DIR}/VideoRefer-Bench-Q/ \
            --question-file ${EVAL_DATA_DIR}/VideoRefer-Bench-Q/VideoRefer-Bench-Q.json \
            --output-file ${OUTPUT_DIR}/videorefer-bench-q/answers/${CKPT_NAME}/${CHUNKS}_${IDX}.json \
            --num-chunks $CHUNKS \
            --chunk-idx $IDX \
            --mode single &
    done

    wait

    # Clear out the output file if it exists.
    > "$output_file"

    # Loop through the indices and concatenate each file.
    for IDX in $(seq 0 $((CHUNKS-1))); do
        cat ${OUTPUT_DIR}/videorefer-bench-q/answers/${CKPT_NAME}/${CHUNKS}_${IDX}.json >> "$output_file"
    done
fi

python videorefer/eval/eval_videorefer_bench_q.py \
    --pred-path $output_file


