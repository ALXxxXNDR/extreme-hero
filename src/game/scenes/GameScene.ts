import Phaser from 'phaser'
import { gameAudio } from '../audio'
import { COLORS, FONT_FAMILY } from '../palette'
import { PATCHES, patchById } from '../patches'
import type { PatchId, PatchModule, RunState } from '../types'

type PhysicsRectangle = Phaser.GameObjects.Rectangle & { body: Phaser.Physics.Arcade.Body }
type PhysicsObject = Phaser.Types.Physics.Arcade.GameObjectWithBody
type TargetObject = Phaser.GameObjects.GameObject & { x: number; y: number }

const ARENA = {
  left: 64,
  right: 1216,
  top: 94,
  bottom: 674,
}

const MAX_CHOICES = 4
const BASE_BALL_SPEED = 430

export class GameScene extends Phaser.Scene {
  private state: RunState = 'ready'
  private paddle!: Phaser.Physics.Arcade.Image
  private balls!: Phaser.Physics.Arcade.Group
  private bricks!: Phaser.Physics.Arcade.Group
  private hazards!: Phaser.Physics.Arcade.Group
  private cursors!: Phaser.Types.Input.Keyboard.CursorKeys
  private leftKey?: Phaser.Input.Keyboard.Key
  private rightKey?: Phaser.Input.Keyboard.Key

  private phaseIndex = 0
  private choiceIndex = 0
  private integrity = 3
  private maxIntegrity = 3
  private score = 0
  private combo = 0
  private destroyedBricks = 0
  private initialBrickCount = 1
  private floorShield = 0
  private completingPhase = false
  private invulnerable = false
  private launched = false
  private attackCount = 0
  private paddleDelta = 0

  private merged: PatchId[] = []
  private debt: PatchId[] = []
  private patchPairs: Array<[PatchModule, PatchModule]> = []

  private boss?: PhysicsRectangle
  private bossHp = 0
  private bossMaxHp = 0
  private bossShield = 0
  private bossRevived = false
  private bossAttackCall?: Phaser.Time.TimerEvent
  private debtLeakEvent?: Phaser.Time.TimerEvent

  private phaseText!: Phaser.GameObjects.Text
  private integrityText!: Phaser.GameObjects.Text
  private scoreText!: Phaser.GameObjects.Text
  private progressFill!: Phaser.GameObjects.Rectangle
  private progressText!: Phaser.GameObjects.Text
  private mergedText!: Phaser.GameObjects.Text
  private debtText!: Phaser.GameObjects.Text
  private launchHint!: Phaser.GameObjects.Text
  private bossBarFill?: Phaser.GameObjects.Rectangle
  private bossBarText?: Phaser.GameObjects.Text
  private redWash!: Phaser.GameObjects.Rectangle

  constructor() {
    super('Game')
  }

  create(): void {
    this.resetRun()
    this.cameras.main.fadeIn(260, 5, 6, 17)
    this.cameras.main.setBackgroundColor(COLORS.background)
    this.drawBackground()
    this.createArena()
    this.createPhysicsGroups()
    this.createPaddle()
    this.createHud()
    this.bindInput()
    this.bindDevelopmentShortcuts()

    const shuffled = Phaser.Utils.Array.Shuffle([...PATCHES])
    for (let index = 0; index < MAX_CHOICES; index += 1) {
      this.patchPairs.push([shuffled[index * 2], shuffled[index * 2 + 1]])
    }

    this.time.delayedCall(380, () => this.startPhase())
  }

  update(): void {
    if (!this.paddle?.active || this.state === 'choosing' || this.state === 'won' || this.state === 'lost') {
      return
    }

    this.updatePaddle()
    this.updateAttachedBalls()
    this.limitBallSpeeds()
    this.checkMissedBalls()
    this.cleanupHazards()
  }

  private resetRun(): void {
    this.state = 'ready'
    this.phaseIndex = 0
    this.choiceIndex = 0
    this.integrity = 3
    this.maxIntegrity = 3
    this.score = 0
    this.combo = 0
    this.destroyedBricks = 0
    this.initialBrickCount = 1
    this.floorShield = 0
    this.completingPhase = false
    this.invulnerable = false
    this.launched = false
    this.attackCount = 0
    this.paddleDelta = 0
    this.merged = []
    this.debt = []
    this.patchPairs = []
    this.boss = undefined
    this.bossRevived = false
  }

  private drawBackground(): void {
    const grid = this.add.graphics().setDepth(-5)
    grid.lineStyle(1, COLORS.line, 0.18)
    for (let x = 16; x < 1280; x += 48) grid.lineBetween(x, 0, x, 720)
    for (let y = 0; y < 720; y += 48) grid.lineBetween(0, y, 1280, y)

    this.add.rectangle(640, 42, 1280, 84, COLORS.surface, 0.95).setDepth(-2)
    this.add.rectangle(640, 696, 1280, 48, COLORS.surface, 0.96).setDepth(-2)
    this.redWash = this.add.rectangle(640, 380, 1280, 620, COLORS.debt, 0).setDepth(-4)

    const scan = this.add.rectangle(640, 100, 1150, 2, COLORS.cyan, 0.12).setDepth(-3)
    this.tweens.add({
      targets: scan,
      y: 670,
      alpha: { from: 0.03, to: 0.18 },
      duration: 5200,
      repeat: -1,
      ease: 'Linear',
    })
  }

  private createArena(): void {
    const border = this.add.graphics().setDepth(-1)
    border.lineStyle(2, COLORS.line, 0.8)
    border.strokeRoundedRect(ARENA.left, ARENA.top, ARENA.right - ARENA.left, ARENA.bottom - ARENA.top, 14)
    border.lineStyle(1, COLORS.cyan, 0.2)
    border.strokeRoundedRect(
      ARENA.left + 5,
      ARENA.top + 5,
      ARENA.right - ARENA.left - 10,
      ARENA.bottom - ARENA.top - 10,
      10,
    )

    this.physics.world.setBounds(
      ARENA.left,
      ARENA.top,
      ARENA.right - ARENA.left,
      ARENA.bottom - ARENA.top + 52,
      true,
      true,
      true,
      false,
    )
  }

  private createPhysicsGroups(): void {
    this.balls = this.physics.add.group({
      allowGravity: false,
      collideWorldBounds: true,
      bounceX: 1,
      bounceY: 1,
    })
    this.bricks = this.physics.add.group({ allowGravity: false, immovable: true })
    this.hazards = this.physics.add.group({ allowGravity: false })

    this.physics.add.collider(this.balls, this.bricks, (ball, brick) => {
      this.onBallHitBrick(ball as PhysicsObject, brick as PhysicsObject)
    })
  }

  private createPaddle(): void {
    this.paddle = this.physics.add.image(640, 636, 'paddle')
    this.paddle.setImmovable(true).setDepth(12)
    this.paddle.body!.setSize(180, 22).setOffset(5, 4)

    this.physics.add.collider(this.balls, this.paddle, (ball) => {
      this.onBallHitPaddle(ball as Phaser.Physics.Arcade.Image)
    })
    this.physics.add.overlap(this.hazards, this.paddle, (_, hazard) => {
      this.onHazardHit(hazard as Phaser.Physics.Arcade.Image)
    })
  }

  private createHud(): void {
    const topStyle: Phaser.Types.GameObjects.Text.TextStyle = {
      fontFamily: FONT_FAMILY,
      fontSize: '15px',
      fontStyle: '800',
      color: COLORS.muted,
      letterSpacing: 1.5,
    }

    this.phaseText = this.add.text(66, 30, 'BUILD 01 / 04', topStyle).setOrigin(0, 0.5)
    this.integrityText = this.add.text(640, 30, '', {
      ...topStyle,
      color: '#ff8a9a',
    }).setOrigin(0.5)
    this.scoreText = this.add.text(1214, 30, 'SCORE 000000', topStyle).setOrigin(1, 0.5)

    this.add.rectangle(640, 66, 530, 8, COLORS.line, 0.72)
    this.progressFill = this.add.rectangle(377, 66, 526, 5, COLORS.cyan, 1).setOrigin(0, 0.5)
    this.progressFill.scaleX = 0
    this.progressText = this.add
      .text(640, 82, 'COMPILE 0%', {
        fontFamily: FONT_FAMILY,
        fontSize: '11px',
        fontStyle: '800',
        color: COLORS.muted,
        letterSpacing: 2,
      })
      .setOrigin(0.5)

    this.mergedText = this.add
      .text(66, 697, 'MERGED  —', {
        fontFamily: FONT_FAMILY,
        fontSize: '13px',
        fontStyle: '800',
        color: '#65e5ff',
      })
      .setOrigin(0, 0.5)

    this.debtText = this.add
      .text(1214, 697, 'TECH DEBT  —', {
        fontFamily: FONT_FAMILY,
        fontSize: '13px',
        fontStyle: '800',
        color: '#ff7181',
      })
      .setOrigin(1, 0.5)

    this.launchHint = this.add
      .text(640, 588, '클릭 또는 SPACE로 컴파일 시작', {
        fontFamily: FONT_FAMILY,
        fontSize: '15px',
        fontStyle: '800',
        color: '#bcefff',
        backgroundColor: '#0b1424cc',
        padding: { x: 16, y: 9 },
      })
      .setOrigin(0.5)
      .setDepth(30)
      .setVisible(false)

    this.updateHud()
  }

  private bindInput(): void {
    this.cursors = this.input.keyboard!.createCursorKeys()
    this.leftKey = this.input.keyboard?.addKey(Phaser.Input.Keyboard.KeyCodes.A)
    this.rightKey = this.input.keyboard?.addKey(Phaser.Input.Keyboard.KeyCodes.D)

    const launch = (): void => {
      gameAudio.unlock()
      if ((this.state === 'playing' || this.state === 'boss') && !this.launched) this.launchBalls()
    }
    this.input.on('pointerdown', launch)
    this.input.keyboard?.on('keydown-SPACE', launch)
  }

  private bindDevelopmentShortcuts(): void {
    if (!import.meta.env.DEV) return
    this.input.keyboard?.on('keydown-K', () => {
      if (this.state !== 'playing' || this.completingPhase) return
      this.bricks.getChildren().forEach((child) => {
        const brick = child as PhysicsRectangle
        const sheen = brick.getData('sheen') as Phaser.GameObjects.Rectangle | undefined
        sheen?.destroy()
        brick.destroy()
      })
      this.completePhase()
    })
    this.input.keyboard?.on('keydown-J', () => {
      if (this.state === 'boss') this.finishRun(true)
    })
  }

  private updatePaddle(): void {
    const pointer = this.input.activePointer
    const keyboardDirection = Number(this.cursors.right.isDown || this.rightKey?.isDown) -
      Number(this.cursors.left.isDown || this.leftKey?.isDown)

    let targetX = this.paddle.x
    if (keyboardDirection !== 0) targetX += keyboardDirection * 12
    else if (pointer.active || pointer.wasTouch) targetX = pointer.worldX

    const halfWidth = this.paddle.displayWidth / 2
    const previousX = this.paddle.x
    this.paddle.x = Phaser.Math.Clamp(targetX, ARENA.left + halfWidth, ARENA.right - halfWidth)
    this.paddleDelta = this.paddle.x - previousX
    ;(this.paddle.body as Phaser.Physics.Arcade.Body).updateFromGameObject()
  }

  private updateAttachedBalls(): void {
    if (this.launched) return
    this.balls.getChildren().forEach((child, index) => {
      const ball = child as Phaser.Physics.Arcade.Image
      if (!ball.active) return
      const offset = (index - (this.balls.countActive(true) - 1) / 2) * 25
      ball.setPosition(this.paddle.x + offset, this.paddle.y - 26)
      ball.setVelocity(0, 0)
    })
  }

  private startPhase(): void {
    this.state = 'playing'
    this.completingPhase = false
    this.launched = false
    this.combo = 0
    this.destroyedBricks = 0
    this.floorShield = this.merged.includes('firewall') ? 1 : 0
    this.phaseText.setText(`BUILD ${String(this.phaseIndex + 1).padStart(2, '0')} / 04`)
    this.progressFill.setVisible(true)
    this.progressText.setVisible(true)
    this.redWash.setAlpha(this.phaseIndex * 0.018 + this.debt.length * 0.012)

    this.clearField()
    this.generateBrickPattern(this.phaseIndex)
    this.initialBrickCount = Math.max(1, this.bricks.countActive(true))
    this.spawnRoundBalls()
    this.launchHint.setVisible(true).setAlpha(1)
    this.tweens.add({ targets: this.launchHint, alpha: 0.45, duration: 700, yoyo: true, repeat: -1 })
    this.scheduleDebtLeaks()
    this.updateHud()
    this.showBanner(`BUILD TEST ${String(this.phaseIndex + 1).padStart(2, '0')}`, '블록을 제거해 패치를 검증하세요', COLORS.cyan)
  }

  private generateBrickPattern(phase: number): void {
    const rows = phase < 2 ? 2 : 3
    const columns = phase % 2 === 0 ? 6 : 7
    const brickWidth = 126
    const brickHeight = 34
    const gapX = 14
    const gapY = 13
    const fullWidth = columns * brickWidth + (columns - 1) * gapX
    const startX = 640 - fullWidth / 2 + brickWidth / 2
    const palette = [0x163b59, 0x19395f, 0x233465, 0x372b62]

    for (let row = 0; row < rows; row += 1) {
      for (let column = 0; column < columns; column += 1) {
        if (phase === 2 && row === 1 && (column === 0 || column === columns - 1)) continue
        if (phase === 3 && row === 0 && column % 3 === 1) continue
        const x = startX + column * (brickWidth + gapX)
        const y = 174 + row * (brickHeight + gapY)
        const fortified = this.debt.includes('firewall') && (row + column) % 5 === 0
        this.createBrick(x, y, brickWidth, brickHeight, fortified ? 2 : 1, palette[phase], false)
      }
    }
  }

  private createBrick(
    x: number,
    y: number,
    width = 126,
    height = 34,
    hp = 1,
    color = 0x19395f,
    recursive = false,
  ): PhysicsRectangle {
    const brick = this.add
      .rectangle(x, y, width, height, color, 0.96)
      .setStrokeStyle(1.5, hp > 1 ? COLORS.debt : COLORS.cyan, hp > 1 ? 0.75 : 0.45)
    this.physics.add.existing(brick)
    const physicsBrick = brick as PhysicsRectangle
    physicsBrick.body.setImmovable(true)
    physicsBrick.body.moves = false
    physicsBrick.setData({ hp, maxHp: hp, recursive })
    this.bricks.add(physicsBrick)

    const sheen = this.add.rectangle(x, y - height * 0.25, width - 12, 2, COLORS.white, 0.16)
    physicsBrick.setData('sheen', sheen)
    return physicsBrick
  }

  private spawnRoundBalls(): void {
    const count = this.merged.includes('multithread') ? 2 : 1
    for (let index = 0; index < count; index += 1) {
      this.spawnBall(this.paddle.x + (index - (count - 1) / 2) * 25, this.paddle.y - 26, true)
    }
  }

  private spawnBall(x: number, y: number, attached = false, temporary = false): Phaser.Physics.Arcade.Image {
    const ball = this.physics.add.image(x, y, 'ball')
    this.balls.add(ball)
    ball.setCircle(8, 10, 10).setBounce(1, 1).setCollideWorldBounds(true).setDepth(10)
    ball.setData({ attached, temporary, damage: this.merged.includes('overclock') ? 1.35 : 1 })
    if (!attached) {
      const angle = Phaser.Math.DegToRad(Phaser.Math.Between(220, 320))
      const speed = this.currentBallSpeed()
      ball.setVelocity(Math.cos(angle) * speed, Math.sin(angle) * speed)
    }
    if (temporary) this.time.delayedCall(7000, () => ball.active && ball.destroy())
    return ball
  }

  private launchBalls(): void {
    if (this.balls.countActive(true) === 0) return
    this.launched = true
    this.launchHint.setVisible(false)
    this.tweens.killTweensOf(this.launchHint)
    const activeBalls = this.balls.getChildren().filter((child) => child.active)
    activeBalls.forEach((child, index) => {
      const ball = child as Phaser.Physics.Arcade.Image
      ball.setData('attached', false)
      const horizontal = activeBalls.length === 1 ? Phaser.Math.Between(-140, 140) : (index === 0 ? -150 : 150)
      const velocity = new Phaser.Math.Vector2(horizontal, -420).normalize().scale(this.currentBallSpeed())
      ball.setVelocity(velocity.x, velocity.y)
    })
    gameAudio.tone(520, 0.09, 'triangle', 0.04)
  }

  private currentBallSpeed(): number {
    return BASE_BALL_SPEED * (this.merged.includes('overclock') ? 1.14 : 1)
  }

  private onBallHitPaddle(ball: Phaser.Physics.Arcade.Image): void {
    if (ball.body!.velocity.y < 0) return
    const relative = Phaser.Math.Clamp((ball.x - this.paddle.x) / (this.paddle.displayWidth / 2), -0.92, 0.92)
    let targetX = relative * 0.82 + Phaser.Math.Clamp(this.paddleDelta / 24, -0.34, 0.34)

    if (this.merged.includes('targeting')) {
      const target = this.findNearestTarget(ball.x)
      if (target) targetX = Phaser.Math.Clamp((target.x - ball.x) / 360, -0.9, 0.9)
    }

    if (this.state === 'boss' && this.boss?.active) {
      const bossAim = Phaser.Math.Clamp((this.boss.x - ball.x) / 360, -0.86, 0.86)
      targetX = Phaser.Math.Linear(targetX, bossAim, 0.72)
    }

    if (Math.abs(targetX) < 0.13) targetX = Phaser.Math.RND.sign() * Phaser.Math.FloatBetween(0.18, 0.32)

    const direction = new Phaser.Math.Vector2(targetX, -1).normalize().scale(this.currentBallSpeed())
    this.time.delayedCall(0, () => ball.active && ball.setVelocity(direction.x, direction.y))
    gameAudio.tone(260 + Math.abs(relative) * 160, 0.045, 'sine', 0.018)
  }

  private findNearestTarget(x: number): TargetObject | undefined {
    const candidates = (this.state === 'boss' && this.boss?.active ? [this.boss] : this.bricks.getChildren()) as TargetObject[]
    return candidates
      .filter((item) => item.active)
      .sort((a, b) => {
        return Math.abs(a.x - x) - Math.abs(b.x - x)
      })[0]
  }

  private onBallHitBrick(ballObject: PhysicsObject, brickObject: PhysicsObject): void {
    const ball = ballObject as Phaser.Physics.Arcade.Image
    const brick = brickObject as PhysicsRectangle
    if (!ball.active || !brick.active) return

    const hp = Number(brick.getData('hp') ?? 1) - Number(ball.getData('damage') ?? 1)
    brick.setData('hp', hp)
    this.combo += 1
    this.score += 80 + Math.min(20, this.combo) * 5
    this.emitBurst(ball.x, ball.y, hp <= 0 ? COLORS.cyan : COLORS.debt, hp <= 0 ? 7 : 3)
    gameAudio.tone(hp <= 0 ? 360 + Math.min(this.combo, 14) * 14 : 150, 0.055, 'square', 0.018)

    if (hp <= 0) this.destroyBrick(brick)
    else {
      brick.setFillStyle(COLORS.debtDark, 1)
      this.tweens.add({ targets: brick, alpha: 0.45, duration: 60, yoyo: true })
    }
    if (Math.abs(ball.body!.velocity.x) < 85) {
      ball.body!.velocity.x = Phaser.Math.RND.sign() * Phaser.Math.Between(115, 165)
    }
    this.updateHud()
  }

  private destroyBrick(brick: PhysicsRectangle, countForCombo = true): void {
    if (!brick.active) return
    const x = brick.x
    const y = brick.y
    const recursive = Boolean(brick.getData('recursive'))
    const sheen = brick.getData('sheen') as Phaser.GameObjects.Rectangle | undefined
    sheen?.destroy()
    brick.destroy()
    this.destroyedBricks += 1

    if (this.state === 'playing' && this.debt.includes('recursion') && !recursive && Math.random() < 0.16) {
      this.time.delayedCall(240, () => {
        if (this.state === 'playing') {
          this.createBrick(
            Phaser.Math.Clamp(x + Phaser.Math.Between(-50, 50), 140, 1140),
            Phaser.Math.Clamp(y + Phaser.Math.Between(-18, 24), 150, 340),
            74,
            24,
            1,
            COLORS.debtDark,
            true,
          )
          this.initialBrickCount += 1
          this.showToast('DEBT LEAK · 버그가 복제되었습니다', COLORS.debt)
        }
      })
    }

    if (countForCombo && this.merged.includes('recursion') && this.combo > 0 && this.combo % 8 === 0) {
      this.spawnBall(this.paddle.x, this.paddle.y - 34, false, true)
      this.showToast('MERGED · 에코 볼 생성', COLORS.cyan)
    }

    if (countForCombo && this.merged.includes('hotfix') && this.destroyedBricks % 7 === 0) {
      const target = Phaser.Utils.Array.GetRandom(this.bricks.getChildren().filter((item) => item.active)) as
        | PhysicsRectangle
        | undefined
      if (target) {
        this.time.delayedCall(90, () => {
          if (target.active) {
            this.emitBurst(target.x, target.y, COLORS.yellow, 11)
            this.destroyBrick(target, false)
            this.showToast('MERGED · 핫픽스 연쇄 수정', COLORS.yellow)
            this.checkPhaseCompletion()
          }
        })
      }
    }

    this.checkPhaseCompletion()
  }

  private checkPhaseCompletion(): void {
    if (this.state !== 'playing' || this.completingPhase) return
    this.time.delayedCall(30, () => {
      if (this.state === 'playing' && this.bricks.countActive(true) === 0 && !this.completingPhase) {
        this.completePhase()
      }
    })
  }

  private completePhase(): void {
    this.completingPhase = true
    this.state = 'choosing'
    this.debtLeakEvent?.remove(false)
    this.balls.clear(true, true)
    this.hazards.clear(true, true)
    this.launchHint.setVisible(false)
    this.score += 500 + this.integrity * 100
    this.updateHud()
    gameAudio.chord([330, 440, 660], 0.14)
    this.cameras.main.flash(180, 32, 215, 255, false)
    this.time.delayedCall(380, () => this.showPatchChoice())
  }

  private showPatchChoice(): void {
    const pair = this.patchPairs[this.choiceIndex]
    if (!pair) return

    let resolved = false
    const overlay = this.add.container(0, 0).setDepth(100)
    const blocker = this.add.rectangle(640, 360, 1280, 720, 0x050711, 0.94).setInteractive()
    overlay.add(blocker)

    const kicker = this.add
      .text(640, 74, `PATCH REVIEW ${String(this.choiceIndex + 1).padStart(2, '0')} / 04`, {
        fontFamily: FONT_FAMILY,
        fontSize: '15px',
        fontStyle: '800',
        color: '#20d7ff',
        letterSpacing: 3,
      })
      .setOrigin(0.5)
    const title = this.add
      .text(640, 116, '하나를 병합하세요', {
        fontFamily: FONT_FAMILY,
        fontSize: '34px',
        fontStyle: '900',
        color: COLORS.text,
      })
      .setOrigin(0.5)
    const subtitle = this.add
      .text(640, 154, '선택하지 않은 패치는 기술 부채가 되어 돌아옵니다.', {
        fontFamily: FONT_FAMILY,
        fontSize: '16px',
        color: COLORS.muted,
      })
      .setOrigin(0.5)
    overlay.add([kicker, title, subtitle])

    const cards = pair.map((patch, index) => this.createPatchCard(390 + index * 500, 410, patch, index + 1))
    overlay.add(cards)

    const select = (selectedIndex: number): void => {
      if (resolved) return
      resolved = true
      const selected = pair[selectedIndex]
      const rejected = pair[selectedIndex === 0 ? 1 : 0]
      this.commitPatch(selected, rejected)

      const selectedCard = cards[selectedIndex]
      const rejectedCard = cards[selectedIndex === 0 ? 1 : 0]
      this.tweens.add({
        targets: selectedCard,
        x: -250,
        alpha: 0,
        duration: 360,
        ease: 'Back.easeIn',
      })
      this.tweens.add({
        targets: rejectedCard,
        x: 1530,
        alpha: 0,
        duration: 440,
        ease: 'Back.easeIn',
      })
      this.tweens.add({
        targets: [kicker, title, subtitle, blocker],
        alpha: 0,
        duration: 360,
        onComplete: () => {
          overlay.destroy(true)
          if (this.choiceIndex >= MAX_CHOICES) this.startBossSequence()
          else {
            this.phaseIndex += 1
            this.startPhase()
          }
        },
      })
    }

    cards.forEach((card, index) => {
      const hitArea = card.getData('hitArea') as Phaser.GameObjects.Rectangle
      hitArea.on('pointerdown', () => select(index))
    })

    this.input.keyboard?.once('keydown-ONE', () => select(0))
    this.input.keyboard?.once('keydown-TWO', () => select(1))
  }

  private createPatchCard(x: number, y: number, patch: PatchModule, shortcut: number): Phaser.GameObjects.Container {
    const card = this.add.container(x, y)
    const shadow = this.add.rectangle(8, 10, 410, 430, 0x000000, 0.34)
    const panel = this.add
      .rectangle(0, 0, 410, 430, COLORS.surfaceRaised, 1)
      .setStrokeStyle(2, COLORS.line, 1)
      .setInteractive({ useHandCursor: true })
    card.setData('hitArea', panel)

    const index = this.add
      .text(-170, -182, `0${shortcut}`, {
        fontFamily: FONT_FAMILY,
        fontSize: '14px',
        fontStyle: '800',
        color: COLORS.muted,
      })
      .setOrigin(0, 0.5)
    const code = this.add
      .text(170, -182, patch.code, {
        fontFamily: 'ui-monospace, SFMono-Regular, monospace',
        fontSize: '12px',
        fontStyle: '700',
        color: '#20d7ff',
      })
      .setOrigin(1, 0.5)
    const symbolCircle = this.add.circle(0, -112, 40, COLORS.cyan, 0.12).setStrokeStyle(2, COLORS.cyan, 0.7)
    const symbol = this.add
      .text(0, -112, patch.symbol, {
        fontFamily: FONT_FAMILY,
        fontSize: '30px',
        fontStyle: '800',
        color: '#c7f6ff',
      })
      .setOrigin(0.5)
    const name = this.add
      .text(0, -50, patch.name, {
        fontFamily: FONT_FAMILY,
        fontSize: '25px',
        fontStyle: '900',
        color: COLORS.text,
      })
      .setOrigin(0.5)

    const mergeLabel = this.add
      .text(-164, 0, 'MERGE', {
        fontFamily: FONT_FAMILY,
        fontSize: '12px',
        fontStyle: '900',
        color: '#20d7ff',
        letterSpacing: 2,
      })
      .setOrigin(0, 0.5)
    const mergeTitle = this.add
      .text(-164, 26, patch.mergeTitle, {
        fontFamily: FONT_FAMILY,
        fontSize: '17px',
        fontStyle: '800',
        color: '#eafaff',
      })
      .setOrigin(0, 0.5)
    const mergeDescription = this.add
      .text(-164, 52, patch.mergeDescription, {
        fontFamily: FONT_FAMILY,
        fontSize: '14px',
        color: '#aebdd2',
        wordWrap: { width: 328 },
      })
      .setOrigin(0, 0)

    const debtPanel = this.add.rectangle(0, 132, 354, 92, COLORS.debtDark, 0.58).setStrokeStyle(1, COLORS.debt, 0.4)
    const debtLabel = this.add
      .text(-164, 105, 'IF REJECTED · TECH DEBT', {
        fontFamily: FONT_FAMILY,
        fontSize: '11px',
        fontStyle: '900',
        color: '#ff7181',
        letterSpacing: 1.2,
      })
      .setOrigin(0, 0.5)
    const debtDescription = this.add
      .text(-164, 130, patch.debtDescription, {
        fontFamily: FONT_FAMILY,
        fontSize: '14px',
        fontStyle: '700',
        color: '#ffd9df',
        wordWrap: { width: 328 },
      })
      .setOrigin(0, 0)

    const choose = this.add
      .text(0, 190, `${shortcut}  병합하기`, {
        fontFamily: FONT_FAMILY,
        fontSize: '14px',
        fontStyle: '900',
        color: '#07101a',
        backgroundColor: '#20d7ff',
        padding: { x: 24, y: 10 },
      })
      .setOrigin(0.5)

    card.add([
      shadow,
      panel,
      index,
      code,
      symbolCircle,
      symbol,
      name,
      mergeLabel,
      mergeTitle,
      mergeDescription,
      debtPanel,
      debtLabel,
      debtDescription,
      choose,
    ])

    panel.on('pointerover', () => {
      panel.setStrokeStyle(2, COLORS.cyan, 1)
      this.tweens.add({ targets: card, y: y - 8, duration: 120 })
    })
    panel.on('pointerout', () => {
      panel.setStrokeStyle(2, COLORS.line, 1)
      this.tweens.add({ targets: card, y, duration: 120 })
    })
    return card
  }

  private commitPatch(selected: PatchModule, rejected: PatchModule): void {
    this.merged.push(selected.id)
    this.debt.push(rejected.id)
    this.choiceIndex += 1

    if (selected.id === 'cache') {
      this.paddle.setScale(1.35, 1)
      this.paddle.body!.setSize(180, 22).setOffset(5, 4)
    }
    if (selected.id === 'rollback') {
      this.maxIntegrity = Math.min(5, this.maxIntegrity + 1)
      this.integrity = Math.min(this.maxIntegrity, this.integrity + 1)
    }

    this.updateHud()
    gameAudio.chord([420, 560, 760], 0.18)
    this.showDecisionFlash(selected, rejected)
  }

  private showDecisionFlash(selected: PatchModule, rejected: PatchModule): void {
    const left = this.add
      .text(72, 360, `MERGED\n${selected.name}`, {
        fontFamily: FONT_FAMILY,
        fontSize: '22px',
        fontStyle: '900',
        color: '#65e5ff',
        align: 'left',
      })
      .setOrigin(0, 0.5)
      .setDepth(140)
      .setAlpha(0)
    const right = this.add
      .text(1208, 360, `TECH DEBT\n${rejected.name}`, {
        fontFamily: FONT_FAMILY,
        fontSize: '22px',
        fontStyle: '900',
        color: '#ff7181',
        align: 'right',
      })
      .setOrigin(1, 0.5)
      .setDepth(140)
      .setAlpha(0)
    this.tweens.add({ targets: [left, right], alpha: 1, duration: 140, yoyo: true, hold: 330, onComplete: () => {
      left.destroy()
      right.destroy()
    } })
  }

  private scheduleDebtLeaks(): void {
    this.debtLeakEvent?.remove(false)
    if (this.debt.length === 0) return
    this.debtLeakEvent = this.time.addEvent({
      delay: Math.max(4300, 6900 - this.debt.length * 480),
      loop: true,
      callback: () => this.leakRandomDebt(),
    })
  }

  private leakRandomDebt(): void {
    if (this.state !== 'playing' || this.debt.length === 0) return
    const debtId = Phaser.Utils.Array.GetRandom(this.debt)
    const patch = patchById[debtId]
    this.showToast(`DEBT LEAK · ${patch.name}`, COLORS.debt)

    switch (debtId) {
      case 'firewall':
        this.fortifyRandomBrick()
        break
      case 'recursion':
      case 'rollback':
      case 'hotfix':
        this.createBrick(Phaser.Math.Between(240, 1040), Phaser.Math.Between(160, 300), 78, 24, 1, COLORS.debtDark, true)
        this.initialBrickCount += 1
        break
      case 'cache':
        this.slowBallsTemporarily()
        break
      default:
        this.spawnHazardVolley(debtId === 'multithread' ? 2 : 1, debtId === 'targeting')
    }
  }

  private fortifyRandomBrick(): void {
    const brick = Phaser.Utils.Array.GetRandom(this.bricks.getChildren().filter((item) => item.active)) as
      | PhysicsRectangle
      | undefined
    if (!brick) return
    brick.setData('hp', Number(brick.getData('hp') ?? 1) + 1)
    brick.setFillStyle(COLORS.debtDark, 1).setStrokeStyle(2, COLORS.debt, 0.9)
    this.emitBurst(brick.x, brick.y, COLORS.debt, 8)
  }

  private slowBallsTemporarily(): void {
    this.balls.getChildren().forEach((child) => {
      const ball = child as Phaser.Physics.Arcade.Image
      if (ball.active) ball.body!.velocity.scale(0.62)
    })
    this.time.delayedCall(1200, () => this.normalizeAllBalls())
  }

  private spawnHazardVolley(count: number, targeting: boolean): void {
    for (let index = 0; index < count; index += 1) {
      const x = count === 1 ? Phaser.Math.Between(220, 1060) : 520 + index * 240
      const hazard = this.physics.add.image(x, 120, 'hazard').setDepth(9)
      hazard.setCircle(7, 8, 8)
      const speed = this.debt.includes('overclock') ? 285 : 235
      const angle = targeting
        ? Phaser.Math.Angle.Between(x, 120, this.paddle.x, this.paddle.y)
        : Phaser.Math.DegToRad(Phaser.Math.Between(70, 110))
      hazard.setVelocity(Math.cos(angle) * speed, Math.sin(angle) * speed)
      this.hazards.add(hazard)
    }
  }

  private startBossSequence(): void {
    this.state = 'ready'
    this.clearField()
    this.phaseText.setText('FINAL BUILD')
    this.progressFill.setVisible(false)
    this.progressText.setVisible(false)
    this.redWash.setAlpha(0.12)
    this.cameras.main.flash(260, 255, 79, 100, false)
    gameAudio.chord([110, 82, 55], 0.45)

    this.showBanner('TECH DEBT DUE', '버린 패치가 최종 보스로 조립됩니다', COLORS.debt)
    this.time.delayedCall(560, () => this.assembleBoss())
  }

  private assembleBoss(): void {
    const boss = this.add
      .rectangle(640, 170, 520, 76, COLORS.surfaceRaised, 1)
      .setStrokeStyle(3, COLORS.debt, 1)
      .setDepth(8)
    this.physics.add.existing(boss)
    this.boss = boss as PhysicsRectangle
    this.boss.body.setImmovable(true)
    this.boss.body.moves = false
    this.bossMaxHp = 20 + this.debt.length * 2
    this.bossHp = this.bossMaxHp
    this.bossShield = this.debt.includes('firewall') ? 2 : 0

    this.add
      .text(640, 170, 'DEBT CORE', {
        fontFamily: 'ui-monospace, SFMono-Regular, monospace',
        fontSize: '17px',
        fontStyle: '900',
        color: '#ffdce1',
        letterSpacing: 2,
      })
      .setOrigin(0.5)
      .setDepth(9)

    this.createBossBar()

    const modulePositions = [
      { x: 470, y: 148 },
      { x: 810, y: 148 },
      { x: 500, y: 220 },
      { x: 780, y: 220 },
    ]
    this.debt.forEach((id, index) => {
      const patch = patchById[id]
      const position = modulePositions[index]
      this.time.delayedCall(index * 230, () => {
        const module = this.add.container(position.x, position.y).setDepth(11).setScale(0)
        const shape = this.add.circle(0, 0, 28, COLORS.debtDark, 1).setStrokeStyle(2, COLORS.debt, 0.9)
        const symbol = this.add
          .text(0, -2, patch.symbol, {
            fontFamily: FONT_FAMILY,
            fontSize: '20px',
            fontStyle: '900',
            color: '#ffdbe0',
          })
          .setOrigin(0.5)
        const label = this.add
          .text(0, 40, patch.name, {
            fontFamily: FONT_FAMILY,
            fontSize: '11px',
            fontStyle: '800',
            color: '#ff8a98',
          })
          .setOrigin(0.5)
        module.add([shape, symbol, label])
        this.tweens.add({ targets: module, scale: 1, duration: 360, ease: 'Back.easeOut' })
        this.emitBurst(position.x, position.y, COLORS.debt, 14)
        gameAudio.tone(120 + index * 24, 0.2, 'sawtooth', 0.03)
      })
    })

    this.time.delayedCall(this.debt.length * 230 + 520, () => this.beginBossFight())
  }

  private beginBossFight(): void {
    if (!this.boss) return
    this.state = 'boss'
    this.launched = false
    this.floorShield = this.merged.includes('firewall') ? 1 : 0
    this.spawnRoundBalls()
    this.launchHint.setText('클릭 또는 SPACE로 부채 청산 시작').setVisible(true).setAlpha(1)
    this.physics.add.collider(this.balls, this.boss, (ball) => {
      this.onBallHitBoss(ball as Phaser.Physics.Arcade.Image)
    })
    this.scheduleBossAttack(900)
    this.updateHud()
  }

  private createBossBar(): void {
    const container = this.add.container(640, 112).setDepth(20)
    const frame = this.add.rectangle(0, 0, 480, 13, COLORS.line, 0.9)
    const fill = this.add.rectangle(-236, 0, 472, 7, COLORS.debt, 1).setOrigin(0, 0.5)
    const text = this.add
      .text(0, -19, 'DEBT COLLECTOR', {
        fontFamily: FONT_FAMILY,
        fontSize: '11px',
        fontStyle: '900',
        color: '#ff9aa5',
        letterSpacing: 2,
      })
      .setOrigin(0.5)
    container.add([frame, fill, text])
    this.bossBarFill = fill
    this.bossBarText = text
  }

  private onBallHitBoss(ball: Phaser.Physics.Arcade.Image): void {
    if (!this.boss?.active || this.state !== 'boss') return
    if (this.bossShield > 0) {
      this.bossShield -= 1
      this.showToast(`FIREWALL · 보호막 ${this.bossShield}`, COLORS.debt)
      this.emitBurst(ball.x, ball.y, COLORS.debt, 9)
      gameAudio.tone(110, 0.12, 'square', 0.035)
      this.updateBossBar()
      return
    }

    const damage = this.merged.includes('overclock') ? 4 : 3
    this.bossHp -= damage
    this.score += Math.round(120 * damage)
    this.emitBurst(ball.x, ball.y, COLORS.cyan, 8)
    this.cameras.main.shake(45, 0.002)
    gameAudio.tone(180 + (1 - this.bossHp / this.bossMaxHp) * 180, 0.055, 'square', 0.022)
    this.updateBossBar()
    this.updateHud()

    if (this.bossHp <= 0) {
      if (this.debt.includes('rollback') && !this.bossRevived) {
        this.bossRevived = true
        this.bossHp = Math.ceil(this.bossMaxHp * 0.22)
        this.showBanner('ROLLBACK EXECUTED', '삭제된 보스 빌드가 복원되었습니다', COLORS.debt)
        this.cameras.main.flash(240, 255, 79, 100, false)
        this.updateBossBar()
      } else this.finishRun(true)
    }
  }

  private scheduleBossAttack(delay: number): void {
    this.bossAttackCall?.remove(false)
    this.bossAttackCall = this.time.delayedCall(delay, () => {
      if (this.state !== 'boss') return
      this.performBossAttack()
      const enraged = this.debt.includes('overclock') && this.bossHp / this.bossMaxHp <= 0.5
      this.scheduleBossAttack(enraged ? 920 : 1540)
    })
  }

  private performBossAttack(): void {
    this.attackCount += 1
    const volley = this.debt.includes('multithread') ? 3 : 1
    this.spawnHazardVolley(volley, this.debt.includes('targeting'))

    if (this.debt.includes('cache') && this.attackCount % 3 === 0) {
      this.slowBallsTemporarily()
      this.showToast('CACHE DEBT · 공 처리 지연', COLORS.debt)
    }
    if (this.debt.includes('recursion') && this.attackCount % 3 === 0) {
      for (let index = 0; index < 2; index += 1) {
        this.createBrick(510 + index * 260, 286, 130, 26, 1, COLORS.debtDark, true)
      }
    }
    if (this.debt.includes('firewall') && this.attackCount % 7 === 0) {
      this.bossShield = Math.min(1, this.bossShield + 1)
      this.showToast('FIREWALL · 보호막 재충전', COLORS.debt)
      this.updateBossBar()
    }
    if (this.debt.includes('hotfix') && this.attackCount % 6 === 0) {
      this.bossHp = Math.min(this.bossMaxHp, this.bossHp + 1)
      this.showToast('HOT FIX · 보스 체력 수리', COLORS.debt)
      this.updateBossBar()
    }
  }

  private updateBossBar(): void {
    if (!this.bossBarFill || !this.bossBarText) return
    this.bossBarFill.scaleX = Phaser.Math.Clamp(this.bossHp / this.bossMaxHp, 0, 1)
    const shield = this.bossShield > 0 ? `  ·  SHIELD ${this.bossShield}` : ''
    this.bossBarText.setText(`DEBT COLLECTOR  ${Math.max(0, Math.ceil(this.bossHp))}/${this.bossMaxHp}${shield}`)
  }

  private checkMissedBalls(): void {
    if (!this.launched || (this.state !== 'playing' && this.state !== 'boss')) return
    this.balls.getChildren().forEach((child) => {
      const ball = child as Phaser.Physics.Arcade.Image
      if (ball.active && ball.y > ARENA.bottom + 28) ball.destroy()
    })

    if (this.balls.countActive(true) === 0) {
      if (this.floorShield > 0) {
        this.floorShield -= 1
        this.showToast('FIREWALL · 낙하 무효화', COLORS.cyan)
        this.relaunchAfterMiss(false)
      } else {
        this.takeDamage()
        if (this.integrity > 0) this.relaunchAfterMiss(false)
      }
    }
  }

  private relaunchAfterMiss(loseDelay = true): void {
    this.launched = false
    this.time.delayedCall(loseDelay ? 700 : 420, () => {
      if (this.state === 'playing' || this.state === 'boss') {
        this.spawnRoundBalls()
        this.launchHint.setVisible(true).setAlpha(1)
      }
    })
  }

  private onHazardHit(hazard: Phaser.Physics.Arcade.Image): void {
    if (!hazard.active || this.invulnerable) return
    hazard.destroy()
    this.takeDamage()
  }

  private takeDamage(): void {
    if (this.invulnerable || this.integrity <= 0) return
    this.integrity -= 1
    this.combo = 0
    this.invulnerable = true
    gameAudio.tone(90, 0.22, 'sawtooth', 0.05)
    this.cameras.main.shake(160, 0.008)
    this.cameras.main.flash(140, 255, 79, 100, false)
    this.tweens.add({ targets: this.paddle, alpha: 0.2, duration: 90, yoyo: true, repeat: 3 })
    this.time.delayedCall(720, () => {
      this.invulnerable = false
      this.paddle.setAlpha(1)
    })
    this.updateHud()
    if (this.integrity <= 0) this.finishRun(false)
  }

  private finishRun(won: boolean): void {
    if (this.state === 'won' || this.state === 'lost') return
    this.state = won ? 'won' : 'lost'
    this.bossAttackCall?.remove(false)
    this.debtLeakEvent?.remove(false)
    this.balls.clear(true, true)
    this.hazards.clear(true, true)
    this.launchHint.setVisible(false)
    if (won) {
      this.score += 3000 + this.integrity * 600
      this.cameras.main.flash(500, 32, 215, 255, false)
      gameAudio.chord([330, 440, 550, 660], 0.34)
    } else gameAudio.chord([180, 130, 82], 0.38)
    this.updateHud()
    this.time.delayedCall(500, () => this.showResult(won))
  }

  private showResult(won: boolean): void {
    const overlay = this.add.container(0, 0).setDepth(200)
    const blocker = this.add.rectangle(640, 360, 1280, 720, 0x050711, 0.94).setInteractive()
    const eyebrow = this.add
      .text(640, 96, won ? 'DEPLOYMENT COMPLETE' : 'DEPLOYMENT ABORTED', {
        fontFamily: FONT_FAMILY,
        fontSize: '15px',
        fontStyle: '900',
        color: won ? '#20d7ff' : '#ff6578',
        letterSpacing: 3,
      })
      .setOrigin(0.5)
    const title = this.add
      .text(640, 166, won ? 'BUILD SHIPPED' : 'BUILD FAILED', {
        fontFamily: FONT_FAMILY,
        fontSize: '54px',
        fontStyle: '900',
        color: COLORS.text,
      })
      .setOrigin(0.5)
    const subtitle = this.add
      .text(640, 218, won ? '기술 부채를 모두 청산했습니다.' : '기술 부채가 현재 빌드를 삼켰습니다.', {
        fontFamily: FONT_FAMILY,
        fontSize: '17px',
        color: COLORS.muted,
      })
      .setOrigin(0.5)

    const summaryPanel = this.add.rectangle(640, 374, 720, 220, COLORS.surfaceRaised, 1).setStrokeStyle(1, COLORS.line, 1)
    const score = this.add
      .text(640, 300, this.score.toString().padStart(6, '0'), {
        fontFamily: 'ui-monospace, SFMono-Regular, monospace',
        fontSize: '38px',
        fontStyle: '900',
        color: '#ffffff',
      })
      .setOrigin(0.5)
    const scoreLabel = this.add
      .text(640, 334, 'FINAL SCORE', {
        fontFamily: FONT_FAMILY,
        fontSize: '11px',
        fontStyle: '900',
        color: COLORS.muted,
        letterSpacing: 2,
      })
      .setOrigin(0.5)
    const merged = this.add
      .text(330, 392, `MERGED\n${this.merged.map((id) => patchById[id].name).join('  ·  ')}`, {
        fontFamily: FONT_FAMILY,
        fontSize: '14px',
        fontStyle: '800',
        color: '#65e5ff',
        wordWrap: { width: 620 },
        align: 'center',
        lineSpacing: 9,
      })
      .setOrigin(0, 0)
    const debt = this.add
      .text(330, 466, `TECH DEBT\n${this.debt.map((id) => patchById[id].name).join('  ·  ')}`, {
        fontFamily: FONT_FAMILY,
        fontSize: '14px',
        fontStyle: '800',
        color: '#ff8290',
        wordWrap: { width: 620 },
        align: 'center',
        lineSpacing: 9,
      })
      .setOrigin(0, 0)

    const retry = this.createResultButton(520, 568, '다시 빌드', COLORS.cyan)
    const menu = this.createResultButton(760, 568, '메인 화면', COLORS.line)
    retry.on('pointerdown', () => this.scene.restart())
    menu.on('pointerdown', () => this.scene.start('Menu'))
    overlay.add([blocker, eyebrow, title, subtitle, summaryPanel, score, scoreLabel, merged, debt, retry, menu])
  }

  private createResultButton(x: number, y: number, label: string, color: number): Phaser.GameObjects.Container {
    const container = this.add.container(x, y)
    const background = this.add
      .rectangle(0, 0, 210, 58, color, color === COLORS.cyan ? 1 : 0.8)
      .setStrokeStyle(2, color === COLORS.cyan ? COLORS.cyanSoft : 0x93a2be, 0.8)
      .setInteractive({ useHandCursor: true })
    const text = this.add
      .text(0, 0, label, {
        fontFamily: FONT_FAMILY,
        fontSize: '17px',
        fontStyle: '900',
        color: color === COLORS.cyan ? '#06111b' : '#f5f7ff',
      })
      .setOrigin(0.5)
    container.add([background, text])
    container.setSize(210, 58).setInteractive({ useHandCursor: true })
    container.on('pointerover', () => container.setScale(1.03))
    container.on('pointerout', () => container.setScale(1))
    return container
  }

  private clearField(): void {
    this.bricks.getChildren().forEach((child) => {
      const brick = child as PhysicsRectangle
      const sheen = brick.getData('sheen') as Phaser.GameObjects.Rectangle | undefined
      sheen?.destroy()
    })
    this.bricks.clear(true, true)
    this.balls.clear(true, true)
    this.hazards.clear(true, true)
  }

  private limitBallSpeeds(): void {
    this.balls.getChildren().forEach((child) => {
      const ball = child as Phaser.Physics.Arcade.Image
      if (!ball.active || !this.launched) return
      const velocity = ball.body!.velocity
      const targetSpeed = this.currentBallSpeed()
      if (velocity.length() < targetSpeed * 0.82 || velocity.length() > targetSpeed * 1.22) {
        velocity.normalize().scale(targetSpeed)
      }
      if (Math.abs(velocity.y) < 110) velocity.y = Math.sign(velocity.y || -1) * 140
    })
  }

  private normalizeAllBalls(): void {
    this.balls.getChildren().forEach((child) => {
      const ball = child as Phaser.Physics.Arcade.Image
      if (ball.active && ball.body!.velocity.lengthSq() > 0) {
        ball.body!.velocity.normalize().scale(this.currentBallSpeed())
      }
    })
  }

  private cleanupHazards(): void {
    this.hazards.getChildren().forEach((child) => {
      const hazard = child as Phaser.Physics.Arcade.Image
      if (hazard.active && (hazard.y > 710 || hazard.x < 20 || hazard.x > 1260)) hazard.destroy()
    })
  }

  private updateHud(): void {
    if (!this.integrityText) return
    const hearts = `${'◆'.repeat(Math.max(0, this.integrity))}${'◇'.repeat(Math.max(0, this.maxIntegrity - this.integrity))}`
    this.integrityText.setText(`BUILD INTEGRITY  ${hearts}`)
    this.scoreText.setText(`SCORE ${this.score.toString().padStart(6, '0')}`)
    this.mergedText.setText(
      `MERGED  ${this.merged.length ? this.merged.map((id) => patchById[id].code).join('  ·  ') : '—'}`,
    )
    this.debtText.setText(
      `TECH DEBT  ${this.debt.length ? this.debt.map((id) => patchById[id].code).join('  ·  ') : '—'}`,
    )

    if (this.state === 'boss') {
      this.progressFill.setVisible(false)
      this.progressText.setVisible(false)
    } else {
      const active = this.bricks?.countActive(true) ?? 0
      const progress = Phaser.Math.Clamp(1 - active / Math.max(1, this.initialBrickCount), 0, 1)
      this.progressFill?.setFillStyle(COLORS.cyan)
      if (this.progressFill) this.progressFill.scaleX = progress
      this.progressText?.setText(`COMPILE ${Math.round(progress * 100)}%`)
    }
  }

  private showBanner(title: string, subtitle: string, color: number): void {
    const container = this.add.container(640, 360).setDepth(80).setAlpha(0)
    const panel = this.add.rectangle(0, 0, 610, 104, COLORS.surface, 0.94).setStrokeStyle(1, color, 0.8)
    const heading = this.add
      .text(0, -16, title, {
        fontFamily: FONT_FAMILY,
        fontSize: '24px',
        fontStyle: '900',
        color: Phaser.Display.Color.IntegerToColor(color).rgba,
        letterSpacing: 2,
      })
      .setOrigin(0.5)
    const description = this.add
      .text(0, 22, subtitle, {
        fontFamily: FONT_FAMILY,
        fontSize: '14px',
        color: '#bac6d9',
      })
      .setOrigin(0.5)
    container.add([panel, heading, description])
    this.tweens.add({
      targets: container,
      alpha: 1,
      y: 348,
      duration: 180,
      yoyo: true,
      hold: 650,
      onComplete: () => container.destroy(true),
    })
  }

  private showToast(message: string, color: number): void {
    const toast = this.add
      .text(640, 104, message, {
        fontFamily: FONT_FAMILY,
        fontSize: '13px',
        fontStyle: '900',
        color: Phaser.Display.Color.IntegerToColor(color).rgba,
        backgroundColor: '#080c18e8',
        padding: { x: 14, y: 8 },
      })
      .setOrigin(0.5)
      .setDepth(70)
      .setAlpha(0)
    this.tweens.add({
      targets: toast,
      y: 118,
      alpha: 1,
      duration: 120,
      yoyo: true,
      hold: 650,
      onComplete: () => toast.destroy(),
    })
  }

  private emitBurst(x: number, y: number, color: number, count: number): void {
    for (let index = 0; index < count; index += 1) {
      const particle = this.add.circle(x, y, Phaser.Math.Between(2, 5), color, 0.9).setDepth(50)
      const angle = Phaser.Math.FloatBetween(0, Math.PI * 2)
      const distance = Phaser.Math.Between(18, 62)
      this.tweens.add({
        targets: particle,
        x: x + Math.cos(angle) * distance,
        y: y + Math.sin(angle) * distance,
        alpha: 0,
        scale: 0.2,
        duration: Phaser.Math.Between(180, 420),
        ease: 'Quad.easeOut',
        onComplete: () => particle.destroy(),
      })
    }
  }
}
