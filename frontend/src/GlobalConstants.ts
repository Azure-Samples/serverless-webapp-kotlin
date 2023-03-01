type Config = {
    FIND_IMAGE: string,
    UPLOAD_URL: string,
}

export const GLOBAL_CONSTANTS = new Map<string, Config>();

GLOBAL_CONSTANTS.set('JAVA', {
        'FIND_IMAGE': `https://<<hostname>>/face/find-person?code=<<key>>`,
        'UPLOAD_URL': `https://<<hostname>>/face/upload-url?code=<<key>>`,
    });

GLOBAL_CONSTANTS.set('PYTHON', {
    'FIND_IMAGE': `https://<<hostname>>/face/find-person?code=<<key>>`,
    'UPLOAD_URL': `https://<<hostname>>/face/upload-url?code=<<key>>`,
});

export const Links_List = [
    {label: 'Source code for the project', link: 'https://github.com/azure-samples/serverless-webapp-kotlin'},
    {label: 'Connect with me @agrawalpankaj16', link: 'https://twitter.com/agrawalpankaj16'},
];
