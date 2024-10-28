# step1.
 #ollama create qwen-patient -f Modelfile # Modelfile is the patient profile, make a LLM instance for a patient

zoc_url="http://xx.xx.xx.xx:xxx"
patient_id="51800"$((1 + RANDOM % 9999)) # create a random id
echo $patient_id;
echo "{\"stream\":false, \"options\":{\"seed\":101, \"temperature\":0, \"messages\":[]}}" > $patient_id-patient.json

echo "
FROM qwen2.5:0.5b
PARAMETER temperature 0
SYSTEM \"\"\"你扮演一个眼科病人，我试图通过向你提问确定你的病情。我知道你不是人类，但是请根据我给你的资料扮演一名病人，用尽量简短清楚回答我的提问。你今年55岁，从事按摩师工作，喜欢钓鱼，5年前患上糖尿病，家族有糖尿病史，你从3个月前开始右眼肿胀，你平时每周有2次40分钟的有氧运动，你的夜间视力不太好，晚上不敢开车，你不使用任何眼药水，过去没有因为眼疾求医。以上信息是你的资料，在后面的问答中，如果有必要就使用这些信息
，保持信息一致性。如果提问超出上述信息范围，请自行发挥。我每次只会问一个问题。\"\"\"
" > $patient_id.modelfile

ollama create $patient_id  -f $patient_id.modelfile # Modelfile is the patient profile, make a LLM instance for a patient


sleep $((1 + RANDOM % 5)); # 1-5 seconds
curl  "$zoc_url/ywApi/query"  -H 'Accept: application/json, text/plain, */*'  -H 'Connection: keep-alive'  -H 'Content-Type: application/json' -H 'isNoCheck: true' --insecure --data-raw '{"messages":[{"role":"user","patient_id":"'${patient_id}'","content":"start_query"}]}' | jq '.' >  $patient_id-doctor.json

exit
for i in `seq 1 2`;do
	echo "-----round $i"
 	tmp=$(mktemp /tmp/tmp.XXXXXX) && jq  --arg response `jq -c '.response' $patient_id-doctor.json` '.messages += [{"role":"user","content":$response}]' $patient_id-patient.json|tee $tmp | curl http://localhost:11434/api/chat -d @- | jq --arg pid $patient_id '.pid=$pid' -c >> log &&  jq --argjson msg $(tail -1 log | jq -c '.message') '.messages += [$msg]' $tmp > $patient_id-patient.json;
	response=$(jq '.messages[-1]|.content' $patient_id-patient.json);
	echo $response;
	curl  'http://123.249.71.73:8059/ywApi/query'  -H 'Accept: application/json, text/plain, */*'  -H 'Connection: keep-alive'  -H 'Content-Type: application/json' -H 'isNoCheck: true' --insecure --data-raw '{"messages":[{"role":"user","patient_id":"'${patient_id}'","content":"'${response}'"}]}' | jq '.' >   $patient_id-doctor.json
done

ollama rm $patient_id

