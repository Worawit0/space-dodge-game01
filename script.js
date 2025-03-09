let spaceship, asteroids = [], score = 0, gameOver = false;
let asteroidSpeed = 3;
let startButton, restartButton;
let stars = [];

function setup() {
    createCanvas(800, 600);
    spaceship = new Spaceship();
    setupButtons();
    for (let i = 0; i < 100; i++) {
        stars.push({ x: random(width), y: random(height), size: random(1, 4) });
    }
}

function setupButtons() {
    startButton = createButton('Start Game')
        .addClass('button')
        .mousePressed(startGame)
        .show();

    restartButton = createButton('Restart Game')
        .addClass('button')
        .mousePressed(restartGame)
        .hide();
}

function startGame() {
    score = 0;
    asteroids = [];
    asteroidSpeed = 3;
    gameOver = false;
    startButton.hide();
    restartButton.hide();
    loop();
}

function restartGame() {
    startGame();
}

function draw() {
    if (gameOver) {
        showGameOver();
        return;
    }

    background(0);
    drawStars();
    updateSpaceship();
    updateAsteroids();
    displayUI();
}

function drawStars() {
    fill(255);
    stars.forEach(star => {
        ellipse(star.x, star.y, star.size);
    });
}

function updateSpaceship() {
    spaceship.update();
    spaceship.display();
}

function updateAsteroids() {
    if (frameCount % 60 === 0) asteroids.push(new Asteroid());

    asteroids.forEach((a, i) => {
        a.update();
        a.display();
        if (spaceship.hits(a)) {
            gameOver = true;
            restartButton.show();
        }
        if (a.offScreen()) {
            asteroids.splice(i, 1);
            score++;
            asteroidSpeed += 0.05;
        }
    });
}

function displayUI() {
    fill(255);
    textSize(24);
    textAlign(LEFT, TOP);
    text("Score: " + score, 20, 20);
}

function showGameOver() {
    fill(255);
    textSize(32);
    textAlign(CENTER, CENTER);
    text("Game Over!", width / 2, height / 2 - 50);
    textSize(24);
    text("Score: " + score, width / 2, height / 2 + 50);
}

class Spaceship {
    constructor() {
        this.x = width / 2;
        this.y = height - 100;
        this.size = 60;
        this.speed = 5;
    }

    update() {
        if (keyIsDown(LEFT_ARROW) && this.x > 0) this.x -= this.speed;
        if (keyIsDown(RIGHT_ARROW) && this.x < width - this.size) this.x += this.speed;
    }

    display() {
        fill(200, 200, 255);
        beginShape();
        vertex(this.x, this.y - this.size);
        vertex(this.x - this.size / 2, this.y + this.size / 2);
        vertex(this.x - this.size / 4, this.y + this.size / 3);
        vertex(this.x + this.size / 4, this.y + this.size / 3);
        vertex(this.x + this.size / 2, this.y + this.size / 2);
        endShape(CLOSE);
        
        fill(255, 0, 0);
        rect(this.x - this.size / 6, this.y + this.size / 3, this.size / 3, this.size / 2);
    }

    hits(a) {
        return this.x < a.x + a.size &&
               this.x + this.size > a.x &&
               this.y < a.y + a.size &&
               this.y + this.size > a.y;
    }
}

class Asteroid {
    constructor() {
        this.x = random(width);
        this.y = -50;
        this.size = random(50, 100);
        this.speed = asteroidSpeed;
        this.offsets = Array.from({length: 6}, () => random(-10, 10));
    }

    update() {
        this.y += this.speed;
    }

    display() {
        fill(169, 169, 169);
        beginShape();
        for (let i = 0; i < 6; i++) {
            let angle = TWO_PI / 6 * i;
            let x = this.x + (this.size / 2 + this.offsets[i]) * cos(angle);
            let y = this.y + (this.size / 2 + this.offsets[i]) * sin(angle);
            vertex(x, y);
        }
        endShape(CLOSE);
    }

    offScreen() {
        return this.y > height;
    }
}