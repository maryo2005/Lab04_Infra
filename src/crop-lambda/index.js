const { S3Client, GetObjectCommand, PutObjectCommand } = require('@aws-sdk/client-s3');
const sharp = require('sharp');

const s3 = new S3Client({ region: process.env.AWS_REGION });
const BUCKET_NAME = process.env.S3_BUCKET;
const PROCESSED_PREFIX = process.env.PROCESSED_PREFIX || 'processed/';

exports.handler = async (event) => {
   // Procesamos cada mensaje del evento SQS
   for (const record of event.Records) {
      try {
         const body = JSON.parse(record.body);
         // S3 event notifications
         if (body.Records) {
            for (const s3Record of body.Records) {
               const srcKey = s3Record.s3.object.key;

               if (!srcKey.startsWith('uploads/')) {
                  continue;
               }

               // Obtenemos la imagen desde S3
               const getCommand = new GetObjectCommand({
                  Bucket: BUCKET_NAME,
                  Key: srcKey
               });

               const response = await s3.send(getCommand);
               const stream = response.Body;

               // Convertimos el stream de datos a Buffer
               const chunks = [];
               for await (const chunk of stream) {
                  chunks.push(chunk);
               }
               const imageBuffer = Buffer.concat(chunks);

               // 1. Redimensionamos la imagen a 40x40
               const resizedBuffer = await sharp(imageBuffer)
                  .resize(40, 40, { fit: 'cover' })
                  .png()
                  .toBuffer();

               // 2. Definimos la máscara vectorial de la estrella de 10 puntas en formato SVG
               const starMask = Buffer.from(`
                        <svg width="40" height="40" viewBox="0 0 40 40" xmlns="http://www.w3.org/2000/svg">
                            <polygon points="20,0 23.5,8.8 33.0,5.9 27.5,14.6 36.2,19.2 26.2,20.0 30.0,29.3 20.8,26.0 16.0,35.0 15.0,25.1 5.0,29.8 10.8,20.8 1.5,16.2 10.8,13.8 6.0,5.2 15.8,9.1" fill="#ffffff"/>
                        </svg>
                    `);

               // 3. Aplicamos la máscara a la imagen para obtener la silueta de estrella
               const processedBuffer = await sharp(resizedBuffer)
                  .ensureAlpha()
                  .composite([
                     { input: starMask, blend: 'dest-in' }
                  ])
                  .toBuffer();

               // Generamos la nueva Key del archivo
               const fileName = srcKey.split('/').pop().replace(/\.[^/.]+$/, "");
               const destKey = `${PROCESSED_PREFIX}${fileName}_star.png`;

               // Guardamos la imagen procesada en S3
               const putCommand = new PutObjectCommand({
                  Bucket: BUCKET_NAME,
                  Key: destKey,
                  Body: processedBuffer,
                  ContentType: 'image/png',
                  ServerSideEncryption: 'AES256'
               });

               await s3.send(putCommand);
               console.log(`Successfully processed image: ${destKey}`);
            }
         }
      } catch (error) {
         console.error('Error processing SQS record:', error);
         throw error;
      }
   }
};