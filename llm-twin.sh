# step1.
 #ollama create qwen-patient -f Modelfile # Modelfile is the patient profile, make a LLM instance for a patient

#patient_id="51800"$((1 + RANDOM % 9999))

#curl http://localhost:11434/api/create -d '{ "name": "'$patient_id-doctor'", "modelfile": "FROM llama2\nSYSTEM "你扮演一个眼科病人" }'
patient_id="51800"

echo "
FROM qwen2.5:0.5b
PARAMETER temperature 0
SYSTEM \"\"\"你扮演一个眼科病人，我试图通过向你提问确定你的病情。我知道你不是人类，但是请根据我给你的资料扮演一名病人，用尽量简短清楚回答我的提问。你今年55岁，从事按摩师工作，喜欢钓鱼，5年前患上糖尿病，家族有糖尿病史，你从3个月前开始右眼肿胀，你平时每周有2次40分钟的有氧运动，你的夜间视力不太好，晚上不敢开车，你不使用任何眼药水，过去没有因为眼疾求医。以上信息是你的资料，在后面的问答中，如果有必要就使用这些信息
，保持信息一致性。如果提问超出上述信息范围，请自行发挥。我每次只会问一个问题。\"\"\"
" > $patient_id-patient.modelfile

echo "
FROM qwen2.5:0.5b
PARAMETER temperature 0
SYSTEM \"\"\"
你是一名眼科医生，你问问题来诊断，询问综合征以缩小病因范围,你的第一个问题是：你最近眼睛不舒服吗？
每次只问一个问题。\"\"\"
" > $patient_id-doctor.modelfile

echo "{\"model\":\"$patient_id-doctor\",\"stream\":false, \"options\":{\"seed\":101, \"temperature\":0}, \"messages\": [ { \"role\": \"assistant\", \"content\": \"请回答：你最近是否眼睛不适？\" } ] }" > $patient_id-doctor.json
echo "{\"model\":\"$patient_id-patient\",\"stream\":false, \"options\":{\"seed\":101, \"temperature\":0}, \"messages\": [ { \"role\": \"user\", \"content\": \"请回答：你最近是否眼睛不适？\" } ]}" > $patient_id-patient.json

ollama create $patient_id-patient  -f $patient_id-patient.modelfile # Modelfile is the patient profile, make a LLM instance for a patient
ollama create $patient_id-doctor -f $patient_id-doctor.modelfile # Modelfile is the patient profile, make a LLM instance for a patient

exit;

for i in `seq 1 2`;do
	echo "loop-$i"
	sleep $((1 + RANDOM % 5)); # 1-10 seconds
	#1. update patient
 	tmp=$(mktemp /tmp/tmp.XXXXXX) 
       	cat $patient_id-patient.json | curl http://localhost:11434/api/chat -d @- > $tmp 
	message=`jq '.message' $tmp`;
	response=`jq '.message.response' $tmp`;
	jq --argjson message $message '.messages += [$message]' $patient_id-patient.json > $tmp
	mv $tmp $patient_id-patient.json

	#1. update doctor
 	tmp=$(mktemp /tmp/tmp.XXXXXX) && jq  --arg response $response '.messages += [{"role":"user","content":$response}]' $patient_id-doctor.json| curl http://localhost:11434/api/chat -d @- > $tmp
	message=`jq '.message' $tmp`;
	response=`jq '.message.response' $tmp`;
	jq --argjson message $message '.messages += [$message]' $patient_id-doctor.json > $tmp
	mv $tmp $patient_id-doctor.json
done
