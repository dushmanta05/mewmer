import github from "../assets/images/svg/github.svg";
import linkedIn from "../assets/images/svg//linkedin.svg";
import twiiterX from "../assets/images/svg/twitter-x.svg";

const Footer = () => {
  return (
    <div className="bg-color text-light py-3">
      <div className="container">
        <p className="copyright text-center m-0">
          © 2026 Mewmer. All rights reserved.
        </p>
        <p className="text-center m-0">
          Developed by{" "}
          <span className="brand">
            <a
              href="https://dushmanta.dev"
              className="text-decoration-none text-light fw-bold"
              rel="noopener"
              target="_blank"
            >
              Dushmanta
            </a>
          </span>
        </p>
        <div className="footer-socials d-flex justify-content-center align-items-center gap-2">
          <a
            href="https://github.com/dushmanta05"
            rel="noopener"
            target="_blank"
          >
            <img src={github} alt="github" color="white" />
          </a>
          <a
            href="https://linkedin.com/in/dushmanta05"
            rel="noopener"
            target="_blank"
          >
            <img alt="linkedin" src={linkedIn} />
          </a>
          <a
            href="https://twitter.com/dushmanta05"
            rel="noopener"
            target="_blank"
          >
            <img alt="twitter" src={twiiterX}></img>
          </a>
        </div>
      </div>
    </div>
  );
};

export default Footer;
