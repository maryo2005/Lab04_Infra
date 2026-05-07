const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const Busboy = require('busboy');
const { v4: uuidv4 } = require('uuid');

const s3 = new S3Client({ region: process.env.AWS_REGION });
const BUCKET_NAME = process.env.S3_BUCKET;
const UPLOAD_PREFIX = process.env.UPLOAD_PREFIX || 'uploads/';

exports.handler = async (event) => {
   return new Promise((resolve, reject) => {
      const busboy = Busboy({
         headers: {
            'content-type': event.headers['content-type'] || event.headers['Content-Type']
         }
      });

      let fileBuffer = null;
      let fileName = '';
      let fileMimeType = '';

      busboy.on('file', (fieldname, file, info) => {
         const { filename, mimeType } = info;
         fileName = `${uuidv4()}-${filename}`;
         fileMimeType = mimeType;

         const chunks = [];
         file.on('data', (chunk) => {
            chunks.push(chunk);
         });

         file.on('end', () => {
            fileBuffer = Buffer.concat(chunks);
         });
      });

      busboy.on('finish', async () => {
         if (!fileBuffer) {
            return resolve({
               statusCode: 400,
               body: JSON.stringify({ message: 'No se ha subido ningún archivo' })
            });
         }

         try {
            const key = `${UPLOAD_PREFIX}${fileName}`;
            const command = new PutObjectCommand({
               Bucket: BUCKET_NAME,
               Key: key,
               Body: fileBuffer,
               ContentType: fileMimeType,
               ServerSideEncryption: 'AES256'
            });

            await s3.send(command);

            resolve({
               statusCode: 200,
               body: JSON.stringify({
                  message: 'La imagen se ha subido correctamente',
                  key: key
               })
            });
         } catch (err) {
            console.error('Error al subir el archivo a S3:', err);
            resolve({
               statusCode: 500,
               body: JSON.stringify({ message: 'Error al procesar la carga' })
            });
         }
      });

      busboy.write(Buffer.from(event.body, event.isBase64Encoded ? 'base64' : 'binary'));
      busboy.end();
   });
};