/**
 * Copyright 2021, Google, Inc.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

'use strict';

// import modules
const PubSub = require(`@google-cloud/pubsub`);
const storage = require('@google-cloud/storage')();
const speech = require('@google-cloud/speech').v1p1beta1;
const client = new speech.SpeechClient();
const ffmpeg = require('fluent-ffmpeg');
const ffmpegPath = require('@ffmpeg-installer/ffmpeg').path;
ffmpeg.setFfmpegPath(ffmpegPath);

exports.srfAudioProcessFunc = (event, context, callback) => {
	const file = event;
	const topicName = "YOUR_TOPIC_NAME"; // TODO: Replace value with your GCP Pub/Sub topic name
	const audioPath = { uri: `gs://${file.bucket}/${file.name}` };
	const readFile = storage.bucket(file.bucket).file(file.name);

	const remoteReadStream = async () => {
		try {
			const res = readFile.createReadStream();
			return res;
		} catch (err) {
			console.error(err);
		};
	};

	function getAudioMetadata(path) {
		// check if file is a wav or flac audio file
		return new Promise((res, rej) => {
			ffmpeg.ffprobe(path, (err, metadata) => {
				if (err) return rej(err);
				const audioMetaData = require('util').inspect(metadata, false, null);
				if (!audioMetaData) throw new Error('Cannot find metadata of ' + path)
				return res(audioMetaData);
			});
		});
	};

	remoteReadStream().then(resRemoteReadStream => {
		getAudioMetadata(resRemoteReadStream).then(res => {

			resRemoteReadStream.destroy();

			// start cleanup - fluent-ffmpeg has an dirtyJSON output
			let resString = res.replace(/[&\/\\#+()$~%'"*?<>{}\s\n\]\[]/g, ''); // remove listed characters
			resString = resString.replace(/:/g, ','); // replace semicolon with commas
			let resArray = resString.split(','); // split string on commas
			// end cleanup

			let sampleRate = resArray[resArray.indexOf('sample_rate') + 1];
			let channels = resArray[resArray.indexOf('channels') + 1];
			let bitsPerSample = resArray[resArray.indexOf('bits_per_sample') + 1];

			// check if file is a wav or flac audio file
			let iExt = file.name.lastIndexOf('.');
			let ext = (iExt < 0) ? '' : file.name.substr(iExt);
			let duration;
			if (ext === '.wav') {
				duration = (file.size / (sampleRate * channels * (bitsPerSample / 8))) / 60;
			}
			else if (ext === '.flac') {
				duration = resArray[resArray.indexOf('duration') + 1];
			}

			let audioConfig = {
				sampleRateHertz: sampleRate,
				languageCode: `en-US`,
				maxAlternatives: 0,
				enableWordTimeOffsets: true,
				useEnhanced: true,
				audioChannelCount: channels,
				enableSeparateRecognitionPerChannel: true,
				model: 'phone_call'
			};

			// send audio file to STT, get job name, add to pub/sub object and publish message
			const audioRequest = {
				audio: audioPath,
				config: audioConfig,
			};

			let pubSubObj = {
				'filename': `gs://${file.bucket}/${file.name}`,
				'duration': duration			
			};

			client
				.longRunningRecognize(audioRequest)
				.then(response => {
					const [operation, initialApiResponse] = response;
					return initialApiResponse;
				})
				.then(response => {
					pubSubObj['sttnameid'] = response.name; // add STT 'name' ID to pubSubObj
				})
				.then(() => {
					const pubSubData = JSON.stringify(pubSubObj);
					const dataBuffer = Buffer.from(pubSubData);
					const pubsub = new PubSub();
					return pubsub
						.topic(topicName)
						.publisher()
						.publish(dataBuffer)
						.then(messageId => {
							console.log(`Message ${messageId} published.`);
							callback(null, 'Success!');
						})
						.catch(err => {
							console.error('ERROR:', err);
						});
				});

		});
	}).catch(err => console.error(err))

};