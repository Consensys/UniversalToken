<style>

.md-typeset h1 {
  color: transparent;
  margin: -20px;
}

.md-content__button, 
.md-sidebar {
    display: none;
  }

.grid-item a {     
    display: inline-block;     
    position: relative;    
    z-index: 1;     
    padding: 35px;     
}

.grid-item img {     
    width: 60%;
}

/*
h1 {
    background-repeat: no-repeat;
    background-attachment: fixed;
    background-position: center center; 
    background-size: cover;
    height: 100%;
    width: auto;
    text-align: center;
}*/


* {
  box-sizing: border-box;
}


.md-typeset h2 {
    color: black;
    font-weight: 300;
    font-size: 23px;
    width: auto;
    align-content: center;
    padding-bottom: 25px;
    margin-top: -30px;
}


.md-main {
    background-color: white;
}


.grid-container {
    display: flex;
    flex-wrap: wrap;
    width: 100%;
    padding: 10px;
    align-items: stretch;
}


.grid-item {

  background-color: hsla(0,0%,100%,0);
  border-radius: 8px;
  -webkit-box-shadow: 0 8px 16px 0 rgb(17 17 17 / 8%);
  box-shadow: 0 8px 16px 0 rgb(17 17 17 / 8%);
  padding: 33px;
  margin: 5px;
  text-align: center;
  align-items: center;
  flex: 32%;
  width: 32%;  

}


@media screen and (max-width: 1000px) {
  .grid-item {
    flex: 32%;
    max-width: 32%;
  }
}


@media screen and (max-width: 800px) {
  .grid-item {
    flex: 48%;
    max-width: 48%;
  }
}


@media screen and (max-width: 600px) {
  .grid-item {
    flex: 100%;
    max-width: 100%;
  }
}

/*
.grid-splash {
    background-color: none;
    margin: 10px 10px;
    font-size: 2em;
    text-align: center;
    width: 100%;
}*/

</style>


<div class="grid-container">
    
  <!--<div class="grid-splash">
    Landing page demo title
  </div>-->

  <div class="grid-item"><a href="/overview/welcome"><h2>Overview</h2>
      <img src="cdn/images/index-icons/5.png" alt=""></a>
  </div>
  
  <div class="grid-item"><a href="/tokens/index"><h2>Token API</h2>  
        <img src="cdn/images/index-icons/10.png" alt=""></a>
  </div>
  
  <div class="grid-item"><a href="/extensions"><h2>Extensions</h2>
        <img src="cdn/images/index-icons/12.png" alt=""></a>
  </div>

  <div class="grid-item"><a href="/contracts/overview"><h2>Contracts</h2>     
        <img src="cdn/images/index-icons/7.png" alt=""></a>
  </div> 

  <div class="grid-item"><a href="/utilities/overview"><h2>Utilities</h2>
        <img src="cdn/images/index-icons/3.png" alt=""></a>
  </div>

  <div class="grid-item"><a href="/api/migrations"><h2>API</h2>       
        <img src="cdn/images/index-icons/4.png" alt=""></a>
  </div>
  
</div>

