import trollFaceImage from "../assets/images/troll-face.png";

export default function Header() {
  return (
    <header className="bg-color">
      <div className="container d-flex justify-content-around align-items-center py-3 text-light">
        <div className="d-flex align-items-center">
          <img src={trollFaceImage} alt="troll face" className="logo" />
          <h2 className="title m-0">Mewmer</h2>
        </div>
        <h4 className="tagline d-none d-md-block m-0">
          Choose image, write text, make your meme 👻
        </h4>
      </div>
    </header>
  );
}
