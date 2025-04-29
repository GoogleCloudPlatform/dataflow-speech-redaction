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

let redactedBucketName = "gs://" + "REDACTED_AUDIO_BUCKET_NAME" // TODO: Replace value with your GCS Bucket Name

const fs = require('fs');
const storage = require('@google-cloud/storage')();
const ffmpeg = require('fluent-ffmpeg');
const ffmpegPath = require('@ffmpeg-installer/ffmpeg').path;
ffmpeg.setFfmpegPath(ffmpegPath);

exports.srfRedactionFunc = (event, context, callback) => {
  console.log('1) Starting Redaction Process');
  const file = event;
  const readFile = storage.bucket(file.bucket).file(file.name);

  const readJsonFile = async () => new Promise((resolve, reject) => {
    let buf = '';
    storage.bucket(file.bucket).file(file.name)
      .createReadStream()
      .on('data', d => (buf += d))
      .on('end', () => resolve(buf))
      .on('error', e => reject(e))
  })

  const downloadFile = async (audioFile, audioFileName) => {
    const options = {
      destination: `/tmp/${audioFileName}`
    };
    try {
      const res = audioFile.download(options);
      return res;
    } catch (err) {
      console.error(err);
    };
  }

  function redactAudio(audioFileName, redaction, tmpAudioFile) {

    let options = []
    for (const element of redaction) {
      options.push({
        filter: "volume",
        options: {
          enable: `between(t,${element.startsecs}, ${element.endsecs})`,
          volume: "0"
        }
      })
    }
    return new Promise((res, rej) => {
      ffmpeg(`/tmp/${audioFileName}`)
        .audioFilters(options)
        .output(`/tmp/${tmpAudioFile}`)
        .on('end', function () {
          return res(true);
        })
        .run();
    });
  };

  return readJsonFile().then(resReadJsonFile => {
    let jsonFile = JSON.parse(resReadJsonFile);
    let audioPathArray = jsonFile.filename.split("/");
    let srcBucketName = audioPathArray[2];
    let audioFileName = audioPathArray[3];

    const audioFile = storage.bucket(srcBucketName).file(audioFileName);
    const tmpAudioFile = `redacted_${audioFileName}`;
    const dstAudioFile = storage.bucket(redactedBucketName);

    let redaction = [];

    let wordList = jsonFile.words.map((list, index) => {
      return list.word
    });

    for (var j = 0; j < jsonFile.dlp.length; j++) {

      let phrase = jsonFile.dlp[j].split(' ');

      if (phrase.length >= 2) {
        phrase.map((word, index) => {
          for (var i = 0; i < jsonFile.words.length; i++) {
            let element = jsonFile.words[i]
            if (i < jsonFile.words.length - 1 & index < phrase.length - 1) {
              if (word === element.word) {
                if (wordList.slice(i, i + phrase.length).toString() === phrase.toString()) {
                  element.index = i
                  let foundWords = jsonFile.words.slice(i, i + phrase.length)
                  for (let wordElement of foundWords) {
                    redaction.push(wordElement)
                  };
                };
              };
            };
          };

        });
      }
      else {
        phrase.map((word, index) => {
          for (var i = 0; i < jsonFile.words.length; i++) {
            let element = jsonFile.words[i]
            if (word === element.word) {
              element.index = i
              redaction.push(element)
            };
          };
        });
      };
    };

    downloadFile(audioFile, audioFileName).then(() => {
      redactAudio(audioFileName, redaction, tmpAudioFile).then(() => {
        console.log('2) Completed Local File Redaction Process')
        dstAudioFile.upload(`/tmp/${tmpAudioFile}`, { resumable: false }).then(() => {
          console.log('3) Upload Local Redacted File to Storage Bucket')
        }).then(() => {
          fs.unlink(`/tmp/${tmpAudioFile}`, (err) => {
            if (err) {
              console.error(err);
              return 0;
            } else {
              console.log('4) Deleted Local File')
              console.log('5) Finished Redaction Process')
              return 0;
            }
          })
        })
        return 0;
      })
      return 0;
    })
    
    return 0;
  }) 
};