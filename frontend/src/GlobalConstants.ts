type Config = {
    FIND_IMAGE: string,
    UPLOAD_URL: string,
}

export const GLOBAL_CONSTANTS = new Map<string, Config>();
GLOBAL_CONSTANTS.set('JAVA', {
        'FIND_IMAGE': `https://api.pankaagr.cloud/face/find-person?code=ac536dd50bc24dd9b3f0b3ffe4e28962`,
        'UPLOAD_URL': `https://api.pankaagr.cloud/face/upload-url?code=ac536dd50bc24dd9b3f0b3ffe4e28962`,
    });

GLOBAL_CONSTANTS.set('PYTHON', {
    'FIND_IMAGE': `https://api.pankaagr.cloud/face/find-person?code=ac536dd50bc24dd9b3f0b3ffe4e28962`,
    'UPLOAD_URL': `https://api.pankaagr.cloud/face/upload-url?code=ac536dd50bc24dd9b3f0b3ffe4e28962`,
});

export const Links_List = [
    {label: 'Source code for the project', link: 'https://github.com/azure-samples/serverless-webapp-kotlin'},
    {label: 'Connect with me @agrawalpankaj16', link: 'https://twitter.com/agrawalpankaj16'},
];
