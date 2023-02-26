import React, {useReducer} from 'react';
import {BrowserRouter as Router, Route, Routes,} from "react-router-dom";

import './App.scss';

import ImageUpload from "./ImageUpload";
import FindImage from "./FindImage";
import Home from "./Home";
import {backendReducer} from "./backendReducer";

const initBackend = 'JAVA';

export const BackendContext = React.createContext([initBackend, null as any]);

const App: React.FunctionComponent = () => {
    const [backend, dispatch] = useReducer(backendReducer, initBackend);

    return (
        <BackendContext.Provider value={[backend, dispatch]}>
            <div className="App">
                <Router>
                    <Routes>
                        <Route path="/" element={<Home/>}/>
                        <Route path="/register" element={<ImageUpload/>}/>
                        <Route path="/find" element={<FindImage/>}/>
                    </Routes>
                </Router>
            </div>
        </BackendContext.Provider>
    );
}

export default App;
