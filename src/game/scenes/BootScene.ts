import Phaser from 'phaser'
import { COLORS } from '../palette'

export class BootScene extends Phaser.Scene {
  constructor() {
    super('Boot')
  }

  create(): void {
    this.createTextures()
    this.scene.start('Menu')
  }

  private createTextures(): void {
    const ball = this.add.graphics()
    ball.fillStyle(COLORS.cyan, 0.12).fillCircle(18, 18, 18)
    ball.fillStyle(COLORS.cyan, 0.32).fillCircle(18, 18, 13)
    ball.fillStyle(COLORS.white, 1).fillCircle(18, 18, 7)
    ball.generateTexture('ball', 36, 36)
    ball.destroy()

    const hazard = this.add.graphics()
    hazard.fillStyle(COLORS.debt, 0.12).fillCircle(15, 15, 15)
    hazard.fillStyle(COLORS.debt, 0.48).fillCircle(15, 15, 10)
    hazard.fillStyle(COLORS.white, 0.95).fillCircle(15, 15, 4)
    hazard.generateTexture('hazard', 30, 30)
    hazard.destroy()

    const paddle = this.add.graphics()
    paddle.fillStyle(COLORS.cyan, 0.14).fillRoundedRect(0, 0, 190, 30, 15)
    paddle.fillStyle(COLORS.cyan, 0.5).fillRoundedRect(5, 5, 180, 20, 10)
    paddle.fillStyle(COLORS.white, 0.95).fillRoundedRect(24, 9, 142, 5, 3)
    paddle.generateTexture('paddle', 190, 30)
    paddle.destroy()

    const particle = this.add.graphics()
    particle.fillStyle(COLORS.white, 1).fillCircle(4, 4, 4)
    particle.generateTexture('particle', 8, 8)
    particle.destroy()
  }
}
