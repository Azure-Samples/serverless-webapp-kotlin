import React from 'react';
import {Button} from "@material-ui/core";
import {useNavigate} from "react-router";
import ButtonAppBar from "./Header";

type FormButton = {
    registerColor: 'default' | 'inherit' | 'primary' | 'secondary',
    findColor: 'default' | 'inherit' | 'primary' | 'secondary',
}

const FormButtons: React.FunctionComponent<FormButton> = ({registerColor, findColor}) => {
    const history = useNavigate();

    const handleShowRegister = () => {
        history('/register');
    };

    const handleShowFind = () => {
        history('/find');
    };

    return (
        <>
            <ButtonAppBar/>
            <div className='action-buttons'>
                <Button href='' variant="contained" color={registerColor} onClick={handleShowRegister} className='action-buttons__register'>
                    Register Your Face
                </Button>
                <Button href='' variant="contained" color={findColor} onClick={handleShowFind}>
                    Find Your Face
                </Button>
            </div>
        </>
    )
};

export default FormButtons;