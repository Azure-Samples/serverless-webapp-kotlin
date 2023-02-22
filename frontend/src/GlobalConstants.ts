type Config = {
    FIND_IMAGE: string,
    UPLOAD_URL: string,
}

export const GLOBAL_CONSTANTS = new Map<string, Config>();

GLOBAL_CONSTANTS.set('JAVA', {
        'FIND_IMAGE': `https://api.pankaagr.cloud/face/find-person?code=81a59a2f816e4902a7a5a77dc772956a`,
        'UPLOAD_URL': `https://api.pankaagr.cloud/face/upload-url?code=81a59a2f816e4902a7a5a77dc772956a`,
    });

GLOBAL_CONSTANTS.set('PYTHON', {
    'FIND_IMAGE': `https://api.pankaagr.cloud/face/find-person?code=81a59a2f816e4902a7a5a77dc772956a`,
    'UPLOAD_URL': `https://api.pankaagr.cloud/face/upload-url?code=81a59a2f816e4902a7a5a77dc772956a`,
});

export const Links_List = [
    {label: 'Source code for the project', link: 'https://github.com/azure-samples/serverless-webapp-kotlin'},
    {label: 'Connect with me @agrawalpankaj16', link: 'https://twitter.com/agrawalpankaj16'},
];
